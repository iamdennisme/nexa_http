use crate::api::error::NativeError;
use crate::api::ffi::{
    NexaHttpBinaryResult, NexaHttpClientConfigArgs, NexaHttpExecuteCallback, NexaHttpRequestArgs,
    clear_last_error_json, store_bootstrap_error,
};
use crate::api::ffi_decode::{read_client_config, read_request};
use crate::api::ffi_result::{
    build_binary_error_result, build_binary_success_result, free_binary_result,
};
use crate::api::request::{NativeHttpOwnedRequestBody, NativeHttpRequest};
use crate::api::response::NativeHttpRawResponse;
use crate::platform::PlatformRuntimeState;
use crate::runtime::client_registry::ClientRegistry;
use crate::runtime::inflight::InflightRequests;
use crate::runtime::request_execution::execute_with_client;
use crate::runtime::tokio_runtime::{build_runtime, default_max_inflight_requests};
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio::sync::Semaphore;

pub struct NexaHttpRuntime<P: PlatformRuntimeState> {
    inner: Arc<NexaHttpRuntimeInner<P>>,
}

struct NexaHttpRuntimeInner<P: PlatformRuntimeState> {
    capabilities: P,
    clients: ClientRegistry,
    inflight_requests: Arc<InflightRequests>,
    tokio: Runtime,
    request_limiter: Arc<Semaphore>,
}

impl<P: PlatformRuntimeState> NexaHttpRuntime<P> {
    pub fn new(capabilities: P) -> Self {
        Self {
            inner: Arc::new(NexaHttpRuntimeInner {
                capabilities,
                clients: ClientRegistry::new(),
                inflight_requests: Arc::new(InflightRequests::new()),
                tokio: build_runtime(),
                request_limiter: Arc::new(Semaphore::new(default_max_inflight_requests())),
            }),
        }
    }

    pub fn client_count_for_test(&self) -> usize {
        self.inner.clients.count()
    }

    pub fn create_client(&self, config_args: *const NexaHttpClientConfigArgs) -> u64 {
        clear_last_error_json();
        let config = match read_client_config(config_args) {
            Ok(config) => config,
            Err(error) => {
                store_bootstrap_error("client_config_decode", error);
                return 0;
            }
        };

        self.inner.capabilities.refresh_for_client_construction();
        let current_state = self.inner.capabilities.current_platform_state();
        match self.inner.clients.create(
            config,
            &current_state.platform_features,
            current_state.proxy_generation,
        ) {
            Ok(client_id) => client_id,
            Err(error) => {
                store_bootstrap_error("client_create", error);
                0
            }
        }
    }

    pub fn execute_async(
        &self,
        client_id: u64,
        request_id: u64,
        request_args: *const NexaHttpRequestArgs,
        callback: NexaHttpExecuteCallback,
    ) -> u8 {
        let Some(callback) = callback else {
            return 0;
        };

        let request = match read_request(request_args) {
            Ok(request) => request,
            Err(error) => {
                let result =
                    Box::into_raw(Box::new(build_binary_error_result(error.into_http_error())))
                        as usize;
                self.inner.tokio.spawn(async move {
                    unsafe {
                        callback(request_id, result as *mut NexaHttpBinaryResult);
                    }
                });
                return 1;
            }
        };

        let request_key = self.inner.inflight_requests.register(client_id, request_id);

        let inner = Arc::clone(&self.inner);
        let inflight_requests = Arc::clone(&self.inner.inflight_requests);
        let task = self.inner.tokio.spawn(async move {
            let _guard = inflight_requests.guard(request_key);
            let result = execute_request_with_limit(Arc::clone(&inner), client_id, request).await;
            if !inner.inflight_requests.commit_callback(request_key) {
                return;
            }
            let result = result
                .map(build_binary_success_result)
                .unwrap_or_else(|error| build_binary_error_result(error.into_http_error()));

            unsafe {
                callback(request_id, Box::into_raw(Box::new(result)));
            }
        });
        let abort_handle = task.abort_handle();
        if self
            .inner
            .inflight_requests
            .install_abort_handle(request_key, abort_handle)
        {
            task.abort();
        }

        1
    }

    pub fn cancel_request(&self, client_id: u64, request_id: u64) -> u8 {
        u8::from(self.inner.inflight_requests.cancel(client_id, request_id))
    }

    pub fn close_client(&self, client_id: u64) {
        self.inner.clients.close(client_id);
    }

    pub fn request_body_alloc(body_len: usize) -> *mut u8 {
        NativeHttpOwnedRequestBody::alloc_raw_parts(body_len)
    }

    /// Releases a request body allocated by [`Self::request_body_alloc`].
    ///
    /// # Safety
    ///
    /// `body_ptr` and `body_len` must describe one live allocation returned by
    /// [`Self::request_body_alloc`], or the canonical null/zero empty value.
    pub unsafe fn request_body_free(body_ptr: *mut u8, body_len: usize) {
        unsafe {
            NativeHttpOwnedRequestBody::free_raw_parts(body_ptr, body_len);
        }
    }

    /// Releases a binary result returned by this runtime.
    ///
    /// # Safety
    ///
    /// `value` must be null or a live result pointer returned by this runtime.
    pub unsafe fn binary_result_free(value: *mut NexaHttpBinaryResult) {
        unsafe {
            free_binary_result(value);
        }
    }
}

async fn execute_request_with_limit<P: PlatformRuntimeState>(
    inner: Arc<NexaHttpRuntimeInner<P>>,
    client_id: u64,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let _permit = inner
        .request_limiter
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| NativeError::new("internal", "Request limiter unexpectedly closed."))?;

    execute_request(inner, client_id, request).await
}

async fn execute_request<P: PlatformRuntimeState>(
    inner: Arc<NexaHttpRuntimeInner<P>>,
    client_id: u64,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let client = inner
        .clients
        .resolve_for_request(&inner.capabilities, client_id, &request.url)?;

    execute_with_client(&client, request).await
}

#[cfg(test)]
mod tests;
