use crate::api::error::{NativeError, NativeHttpError};
use crate::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpHeaderEntry, NexaHttpRequestArgs,
};
use crate::api::request::{NativeHttpClientConfig, NativeHttpHeader, NativeHttpRequest};
use crate::api::response::{NativeHttpOwnedBody, NativeHttpRawResponse};
use crate::platform::{PlatformFeatures, PlatformRuntimeState, apply_proxy_strategy};
use crate::runtime::client_registry::ClientEntry;
use crate::runtime::tokio_runtime::{build_runtime, default_max_inflight_requests};
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::{Client, ClientBuilder, Method};
use serde::de::DeserializeOwned;
use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::ptr::null_mut;
use std::slice::from_raw_parts;
use std::str::FromStr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::runtime::Runtime;
use tokio::sync::Semaphore;

pub struct NexaHttpRuntime<P: PlatformRuntimeState> {
    inner: Arc<NexaHttpRuntimeInner<P>>,
}

struct NexaHttpRuntimeInner<P: PlatformRuntimeState> {
    capabilities: P,
    clients: Mutex<HashMap<u64, ClientEntry>>,
    next_client_id: AtomicU64,
    tokio: Runtime,
    request_limiter: Arc<Semaphore>,
}

impl<P: PlatformRuntimeState> NexaHttpRuntime<P> {
    pub fn new(capabilities: P) -> Self {
        Self {
            inner: Arc::new(NexaHttpRuntimeInner {
                capabilities,
                clients: Mutex::new(HashMap::new()),
                next_client_id: AtomicU64::new(1),
                tokio: build_runtime(),
                request_limiter: Arc::new(Semaphore::new(default_max_inflight_requests())),
            }),
        }
    }

    pub fn client_count_for_test(&self) -> usize {
        self.inner.clients.lock().unwrap().len()
    }

    pub fn create_client(&self, config_json: *const c_char) -> u64 {
        let config = match read_json::<NativeHttpClientConfig>(config_json) {
            Ok(config) => config,
            Err(_) => return 0,
        };

        let current_state = self.inner.capabilities.current_platform_state();
        let client = match build_client(&config, &current_state.platform_features) {
            Ok(client) => client,
            Err(_) => return 0,
        };

        let client_id = self.inner.next_client_id.fetch_add(1, Ordering::Relaxed);
        let entry = ClientEntry::new(
            client,
            config,
            current_state.platform_features.signature(),
            current_state.proxy_generation,
        );
        self.inner.clients.lock().unwrap().insert(client_id, entry);
        client_id
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

        let inner = Arc::clone(&self.inner);
        self.inner.tokio.spawn(async move {
            let result = execute_request_with_limit(inner, client_id, request)
                .await
                .map(build_binary_success_result)
                .unwrap_or_else(|error| build_binary_error_result(error.into_http_error()));

            unsafe {
                callback(request_id, Box::into_raw(Box::new(result)));
            }
        });

        1
    }

    pub fn execute_binary(
        &self,
        client_id: u64,
        request_args: *const NexaHttpRequestArgs,
    ) -> *mut NexaHttpBinaryResult {
        let result = match read_request(request_args) {
            Ok(request) => self
                .inner
                .tokio
                .block_on(execute_request_with_limit(
                    Arc::clone(&self.inner),
                    client_id,
                    request,
                ))
                .map(build_binary_success_result)
                .unwrap_or_else(|error| build_binary_error_result(error.into_http_error())),
            Err(error) => build_binary_error_result(error.into_http_error()),
        };

        Box::into_raw(Box::new(result))
    }

    pub fn close_client(&self, client_id: u64) {
        self.inner.clients.lock().unwrap().remove(&client_id);
    }

    pub fn binary_result_free(value: *mut NexaHttpBinaryResult) {
        if value.is_null() {
            return;
        }

        unsafe {
            binary_result_free_impl(value);
        }
    }
}

pub(crate) unsafe fn binary_result_free_impl(value: *mut NexaHttpBinaryResult) {
    unsafe {
        let mut result = Box::from_raw(value);
        free_header_entries_buffer(result.headers_ptr, result.headers_len);
        if !result.final_url_ptr.is_null() {
            drop(CString::from_raw(result.final_url_ptr));
        }
        if !result.error_json.is_null() {
            drop(CString::from_raw(result.error_json));
        }
        result.free_owned_body();
    }
}

fn read_json<T>(pointer: *const c_char) -> Result<T, NativeError>
where
    T: DeserializeOwned,
{
    if pointer.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null JSON pointer.",
        ));
    }

    let json = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map_err(|error| NativeError::new("invalid_utf8", error.to_string()))?;

    serde_json::from_str(json).map_err(|error| NativeError::new("invalid_json", error.to_string()))
}

fn read_request(
    request_args: *const NexaHttpRequestArgs,
) -> Result<NativeHttpRequest, NativeError> {
    let request_args = unsafe { request_args.as_ref() }.ok_or_else(|| {
        NativeError::new(
            "invalid_argument",
            "Expected a non-null request args pointer.",
        )
    })?;

    let body = if request_args.body_len == 0 {
        Vec::new()
    } else if request_args.body_ptr.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null body pointer when body_len > 0.",
        ));
    } else {
        unsafe { from_raw_parts(request_args.body_ptr, request_args.body_len) }.to_vec()
    };

    let headers = read_request_headers(request_args.headers_ptr, request_args.headers_len)?;

    Ok(NativeHttpRequest {
        method: read_string_parts(
            request_args.method_ptr,
            request_args.method_len,
            "request method",
        )?,
        url: read_string_parts(request_args.url_ptr, request_args.url_len, "request URL")?,
        headers,
        body,
        timeout_ms: if request_args.has_timeout == 0 {
            None
        } else {
            Some(request_args.timeout_ms)
        },
    })
}

fn read_request_headers(
    headers_ptr: *const NexaHttpHeaderEntry,
    headers_len: usize,
) -> Result<HashMap<String, String>, NativeError> {
    if headers_len == 0 {
        return Ok(HashMap::new());
    }
    if headers_ptr.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null headers pointer when headers_len > 0.",
        ));
    }

    let mut headers = HashMap::with_capacity(headers_len);
    for entry in unsafe { from_raw_parts(headers_ptr, headers_len) } {
        let name = read_string_parts(entry.name_ptr, entry.name_len, "request header name")?;
        let value = read_string_parts(entry.value_ptr, entry.value_len, "request header value")?;
        headers.insert(name, value);
    }
    Ok(headers)
}

fn read_string_parts(
    pointer: *const c_char,
    length: usize,
    field_name: &'static str,
) -> Result<String, NativeError> {
    if length == 0 {
        return Ok(String::new());
    }
    if pointer.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            format!("Expected a non-null pointer for {field_name}."),
        ));
    }

    let bytes = unsafe { from_raw_parts(pointer.cast::<u8>(), length) };
    let value = std::str::from_utf8(bytes)
        .map_err(|error| NativeError::new("invalid_utf8", error.to_string()))?;
    Ok(value.to_string())
}

fn build_client(
    config: &NativeHttpClientConfig,
    platform_features: &PlatformFeatures,
) -> Result<Client, NativeError> {
    let mut builder = ClientBuilder::new();

    builder = builder.pool_max_idle_per_host(usize::MAX).tcp_nodelay(true);

    if let Some(timeout_ms) = config.timeout_ms.filter(|value| *value > 0) {
        builder = builder.timeout(Duration::from_millis(timeout_ms));
    }

    if let Some(user_agent) = config.user_agent.as_ref().filter(|value| !value.is_empty()) {
        builder = builder.user_agent(user_agent.clone());
    }

    if !config.default_headers.is_empty() {
        builder =
            builder.default_headers(build_headers(&config.default_headers, "invalid_config")?);
    }
    builder = apply_proxy_strategy(builder, platform_features)
        .map_err(|error| NativeError::new("invalid_proxy", error))?;

    builder
        .build()
        .map_err(|error| NativeError::new("invalid_config", error.to_string()))
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
    let client = resolve_client_for_request(&inner, client_id, &request.url)?;

    execute_request_with_client_async(&client, request).await
}

fn resolve_client_for_request<P: PlatformRuntimeState>(
    inner: &Arc<NexaHttpRuntimeInner<P>>,
    client_id: u64,
    request_url: &str,
) -> Result<Client, NativeError> {
    loop {
        let plan = {
            let clients = inner.clients.lock().unwrap();
            let entry = clients
                .get(&client_id)
                .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
            let current_generation = inner.capabilities.proxy_generation();
            if entry.proxy_generation == current_generation {
                return Ok(entry.client.clone());
            }

            ClientRefreshPlan {
                previous_generation: entry.proxy_generation,
                previous_signature: entry.platform_features_signature.clone(),
                config: entry.config.clone(),
                current_generation,
            }
        };

        let current_state = inner.capabilities.current_platform_state();
        if current_state.proxy_generation != plan.current_generation {
            continue;
        }
        let next_signature = current_state.platform_features.signature();
        let rebuilt_client = if next_signature == plan.previous_signature {
            None
        } else {
            Some(
                build_client(&plan.config, &current_state.platform_features)
                    .map_err(|error| error.with_uri(request_url.to_string()))?,
            )
        };

        let mut clients = inner.clients.lock().unwrap();
        let entry = clients
            .get_mut(&client_id)
            .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;

        if entry.proxy_generation != plan.previous_generation
            || entry.platform_features_signature != plan.previous_signature
        {
            continue;
        }

        if let Some(client) = rebuilt_client {
            entry.client = client;
            entry.platform_features_signature = next_signature;
        }
        entry.proxy_generation = current_state.proxy_generation;
        return Ok(entry.client.clone());
    }
}

#[derive(Clone)]
struct ClientRefreshPlan {
    previous_generation: u64,
    previous_signature: String,
    config: NativeHttpClientConfig,
    current_generation: u64,
}

async fn execute_request_with_client_async(
    client: &Client,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let NativeHttpRequest {
        method,
        url,
        headers,
        body,
        timeout_ms,
    } = request;

    let method = Method::from_str(&method)
        .map_err(|error| NativeError::new("invalid_request", error.to_string()))?;

    let mut builder = client.request(method, &url);

    for (name, value) in &headers {
        let header_name = HeaderName::from_bytes(name.as_bytes()).map_err(|error| {
            let mut details = HashMap::new();
            details.insert("header".to_string(), name.clone());
            NativeError::new("invalid_request", error.to_string()).with_details(details)
        })?;
        let header_value = HeaderValue::from_str(value).map_err(|error| {
            let mut details = HashMap::new();
            details.insert("header".to_string(), name.clone());
            NativeError::new("invalid_request", error.to_string()).with_details(details)
        })?;
        builder = builder.header(header_name, header_value);
    }

    if let Some(timeout_ms) = timeout_ms.filter(|value| *value > 0) {
        builder = builder.timeout(Duration::from_millis(timeout_ms));
    }

    if !body.is_empty() {
        builder = builder.body(body);
    }

    let response = builder
        .send()
        .await
        .map_err(|error| map_reqwest_error(error, &url))?;
    let status_code = response.status().as_u16();

    let mut headers = Vec::<NativeHttpHeader>::new();
    for (name, value) in response.headers() {
        headers.push(NativeHttpHeader {
            name: name.to_string(),
            value: value.to_str().unwrap_or_default().to_string(),
        });
    }

    let final_url = Some(response.url().to_string());
    let body = response
        .bytes()
        .await
        .map_err(|error| map_reqwest_error(error, &url))?;

    Ok(NativeHttpRawResponse {
        status_code,
        headers,
        body: NativeHttpOwnedBody::from_bytes(body.as_ref()),
        final_url,
    })
}

fn build_binary_success_result(response: NativeHttpRawResponse) -> NexaHttpBinaryResult {
    let (headers_ptr, headers_len) = match build_header_entries_buffer(response.headers) {
        Ok(value) => value,
        Err(error) => return build_binary_error_result(error),
    };
    let (final_url_ptr, final_url_len) = match build_string_buffer(response.final_url) {
        Ok(value) => value,
        Err(error) => {
            free_header_entries_buffer(headers_ptr, headers_len);
            return build_binary_error_result(error);
        }
    };

    let mut result = NexaHttpBinaryResult {
        is_success: 1,
        status_code: response.status_code,
        headers_ptr,
        headers_len,
        final_url_ptr,
        final_url_len,
        body_ptr: null_mut(),
        body_len: 0,
        error_json: null_mut(),
    };
    result.set_owned_body(response.body);
    result
}

fn build_binary_error_result(error: NativeHttpError) -> NexaHttpBinaryResult {
    let error_json = match serde_json::to_string(&error)
        .ok()
        .and_then(|json| CString::new(json).ok())
    {
        Some(value) => value.into_raw(),
        None => CString::new(
            r#"{"code":"serialization","message":"Failed to encode error.","is_timeout":false}"#,
        )
        .unwrap()
        .into_raw(),
    };

    NexaHttpBinaryResult {
        is_success: 0,
        status_code: 0,
        headers_ptr: null_mut(),
        headers_len: 0,
        final_url_ptr: null_mut(),
        final_url_len: 0,
        body_ptr: null_mut(),
        body_len: 0,
        error_json,
    }
}

fn build_header_entries_buffer(
    headers: Vec<NativeHttpHeader>,
) -> Result<(*mut NexaHttpHeaderEntry, usize), NativeHttpError> {
    if headers.is_empty() {
        return Ok((null_mut(), 0));
    }

    let mut entries = Vec::<NexaHttpHeaderEntry>::with_capacity(headers.len());
    for header in headers {
        let name = CString::new(header.name).map_err(|_| NativeHttpError {
            code: "serialization".to_string(),
            message: "Failed to encode response header name.".to_string(),
            status_code: None,
            is_timeout: false,
            uri: None,
            details: None,
        })?;
        let value = CString::new(header.value).map_err(|_| NativeHttpError {
            code: "serialization".to_string(),
            message: "Failed to encode response header value.".to_string(),
            status_code: None,
            is_timeout: false,
            uri: None,
            details: None,
        })?;
        let entry = NexaHttpHeaderEntry {
            name_len: name.as_bytes().len(),
            name_ptr: name.into_raw(),
            value_len: value.as_bytes().len(),
            value_ptr: value.into_raw(),
        };
        entries.push(entry);
    }

    let len = entries.len();
    let ptr = entries.as_mut_ptr();
    std::mem::forget(entries);
    Ok((ptr, len))
}

fn build_string_buffer(value: Option<String>) -> Result<(*mut c_char, usize), NativeHttpError> {
    let Some(value) = value else {
        return Ok((null_mut(), 0));
    };
    let value = CString::new(value).map_err(|_| NativeHttpError {
        code: "serialization".to_string(),
        message: "Failed to encode final URL.".to_string(),
        status_code: None,
        is_timeout: false,
        uri: None,
        details: None,
    })?;
    let length = value.as_bytes().len();
    Ok((value.into_raw(), length))
}

fn free_header_entries_buffer(headers_ptr: *mut NexaHttpHeaderEntry, headers_len: usize) {
    if headers_ptr.is_null() || headers_len == 0 {
        return;
    }

    unsafe {
        let entries = Vec::from_raw_parts(headers_ptr, headers_len, headers_len);
        for entry in entries {
            if !entry.name_ptr.is_null() {
                drop(CString::from_raw(entry.name_ptr.cast_mut()));
            }
            if !entry.value_ptr.is_null() {
                drop(CString::from_raw(entry.value_ptr.cast_mut()));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::platform::{PlatformRuntimeView, ProxySettings};
    use std::collections::HashMap;
    use std::ffi::CString;
    use std::os::raw::c_char;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};

    #[derive(Clone)]
    struct CountingCapabilities {
        proxy_settings_calls: Arc<AtomicUsize>,
    }

    impl PlatformRuntimeState for CountingCapabilities {
        fn proxy_generation(&self) -> u64 {
            0
        }

        fn current_platform_state(&self) -> PlatformRuntimeView {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            PlatformRuntimeView::with_proxy_settings(0, ProxySettings::default())
        }
    }

    #[derive(Clone)]
    struct SwitchingProxyCapabilities {
        use_proxy: Arc<AtomicBool>,
        proxy_settings_calls: Arc<AtomicUsize>,
        generation: Arc<AtomicU64>,
    }

    impl PlatformRuntimeState for SwitchingProxyCapabilities {
        fn proxy_generation(&self) -> u64 {
            self.generation.load(Ordering::Relaxed)
        }

        fn current_platform_state(&self) -> PlatformRuntimeView {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            let proxy = if self.use_proxy.load(Ordering::Relaxed) {
                ProxySettings {
                    http: Some("http://127.0.0.1:8888".to_string()),
                    ..ProxySettings::default()
                }
            } else {
                ProxySettings::default()
            };
            PlatformRuntimeView::with_proxy_settings(
                self.generation.load(Ordering::Relaxed),
                proxy,
            )
        }
    }

    #[derive(Clone)]
    struct InvalidProxyCapabilities {
        use_invalid_proxy: Arc<AtomicBool>,
        proxy_settings_calls: Arc<AtomicUsize>,
        generation: Arc<AtomicU64>,
    }

    impl PlatformRuntimeState for InvalidProxyCapabilities {
        fn proxy_generation(&self) -> u64 {
            self.generation.load(Ordering::Relaxed)
        }

        fn current_platform_state(&self) -> PlatformRuntimeView {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            let proxy = if self.use_invalid_proxy.load(Ordering::Relaxed) {
                ProxySettings {
                    http: Some("not a valid proxy url".to_string()),
                    ..ProxySettings::default()
                }
            } else {
                ProxySettings::default()
            };
            PlatformRuntimeView::with_proxy_settings(
                self.generation.load(Ordering::Relaxed),
                proxy,
            )
        }
    }

    #[derive(Clone)]
    struct DelayedGenerationCapabilities {
        delay_refresh: Arc<AtomicBool>,
        proxy_settings_calls: Arc<AtomicUsize>,
        generation: Arc<AtomicU64>,
    }

    impl PlatformRuntimeState for DelayedGenerationCapabilities {
        fn proxy_generation(&self) -> u64 {
            self.generation.load(Ordering::Relaxed)
        }

        fn current_platform_state(&self) -> PlatformRuntimeView {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            if self.delay_refresh.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(50));
            }
            PlatformRuntimeView::with_proxy_settings(
                self.generation.load(Ordering::Relaxed),
                ProxySettings::default(),
            )
        }
    }

    struct TestRequestArgs {
        _method: CString,
        _url: CString,
        args: NexaHttpRequestArgs,
    }

    impl TestRequestArgs {
        fn new(method: &str, url: &str, timeout_ms: u64) -> Self {
            let method = CString::new(method).expect("request method");
            let url = CString::new(url).expect("request url");
            let args = NexaHttpRequestArgs {
                method_ptr: method.as_ptr() as *const c_char,
                method_len: method.as_bytes().len(),
                url_ptr: url.as_ptr() as *const c_char,
                url_len: url.as_bytes().len(),
                headers_ptr: std::ptr::null(),
                headers_len: 0,
                body_ptr: std::ptr::null(),
                body_len: 0,
                timeout_ms,
                has_timeout: 1,
            };
            Self {
                _method: method,
                _url: url,
                args,
            }
        }

        fn as_args(&self) -> *const NexaHttpRequestArgs {
            &self.args
        }
    }

    fn client_config_json() -> CString {
        CString::new(r#"{"default_headers":{},"timeout_ms":null,"user_agent":null}"#)
            .expect("config json")
    }

    fn native_test_request() -> NativeHttpRequest {
        NativeHttpRequest {
            method: "GET".to_string(),
            url: "http://127.0.0.1:9/ping".to_string(),
            headers: HashMap::new(),
            body: Vec::new(),
            timeout_ms: Some(1),
        }
    }

    #[test]
    fn unchanged_generation_reuses_existing_client() {
        let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
        let runtime = NexaHttpRuntime::new(CountingCapabilities {
            proxy_settings_calls: Arc::clone(&proxy_settings_calls),
        });
        let config = client_config_json();
        let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

        let warmed = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(warmed);
        let steady_state = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(steady_state);

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_create,
            "unchanged generation should stay on the fast path after initial client creation",
        );
    }

    #[test]
    fn incremented_generation_rebuilds_once_when_signature_changes() {
        let switch = Arc::new(AtomicBool::new(false));
        let calls = Arc::new(AtomicUsize::new(0));
        let generation = Arc::new(AtomicU64::new(0));
        let runtime = NexaHttpRuntime::new(SwitchingProxyCapabilities {
            use_proxy: Arc::clone(&switch),
            proxy_settings_calls: Arc::clone(&calls),
            generation: Arc::clone(&generation),
        });
        let config = client_config_json();
        let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = calls.load(Ordering::Relaxed);

        let warmup = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(warmup);

        switch.store(true, Ordering::Relaxed);
        generation.store(1, Ordering::Relaxed);

        let refreshed = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(refreshed);
        let steady_state = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(steady_state);

        assert_eq!(
            calls.load(Ordering::Relaxed),
            calls_after_create + 1,
            "a generation change should trigger one rebuild lookup",
        );
    }

    #[test]
    fn invalid_proxy_generation_change_retries_on_next_request() {
        let use_invalid_proxy = Arc::new(AtomicBool::new(false));
        let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
        let generation = Arc::new(AtomicU64::new(0));
        let runtime = NexaHttpRuntime::new(InvalidProxyCapabilities {
            use_invalid_proxy: Arc::clone(&use_invalid_proxy),
            proxy_settings_calls: Arc::clone(&proxy_settings_calls),
            generation: Arc::clone(&generation),
        });
        let config = client_config_json();
        let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

        use_invalid_proxy.store(true, Ordering::Relaxed);
        generation.store(1, Ordering::Relaxed);

        let failed_refresh = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<InvalidProxyCapabilities>::binary_result_free(failed_refresh);
        let first_retry = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<InvalidProxyCapabilities>::binary_result_free(first_retry);

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_create + 2,
            "a failed rebuild leaves the older client generation in place, so the next request retries",
        );
    }

    #[test]
    fn changed_generation_settles_back_to_steady_state_after_concurrency() {
        let delay_refresh = Arc::new(AtomicBool::new(false));
        let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
        let generation = Arc::new(AtomicU64::new(0));
        let runtime = NexaHttpRuntime::new(DelayedGenerationCapabilities {
            delay_refresh: Arc::clone(&delay_refresh),
            proxy_settings_calls: Arc::clone(&proxy_settings_calls),
            generation: Arc::clone(&generation),
        });
        let config = client_config_json();

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

        delay_refresh.store(true, Ordering::Relaxed);
        generation.store(1, Ordering::Relaxed);

        let inner = Arc::clone(&runtime.inner);
        runtime.inner.tokio.block_on(async move {
            let mut tasks = Vec::new();
            for _ in 0..8 {
                let inner = Arc::clone(&inner);
                tasks.push(tokio::spawn(async move {
                    let _ =
                        execute_request_with_limit(inner, client_id, native_test_request()).await;
                }));
            }

            for task in tasks {
                task.await.expect("refresh task should join");
            }
        });

        let calls_after_concurrency = proxy_settings_calls.load(Ordering::Relaxed);
        assert!(
            calls_after_concurrency >= calls_after_create + 1,
            "at least one concurrent request should observe the changed generation",
        );

        let steady_request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);
        let steady_state = runtime.execute_binary(client_id, steady_request.as_args());
        NexaHttpRuntime::<DelayedGenerationCapabilities>::binary_result_free(steady_state);

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_concurrency,
            "once one concurrent request commits the new generation, later steady-state requests should stay on the fast path",
        );
    }
}

fn build_headers(
    headers: &HashMap<String, String>,
    error_code: &'static str,
) -> Result<HeaderMap, NativeError> {
    let mut header_map = HeaderMap::new();
    for (name, value) in headers {
        let header_name = HeaderName::from_bytes(name.as_bytes())
            .map_err(|error| NativeError::new(error_code, error.to_string()))?;
        let header_value = HeaderValue::from_str(value)
            .map_err(|error| NativeError::new(error_code, error.to_string()))?;
        header_map.insert(header_name, header_value);
    }
    Ok(header_map)
}

fn map_reqwest_error(error: reqwest::Error, url: &str) -> NativeError {
    if error.is_timeout() {
        return NativeError::new("timeout", error.to_string())
            .with_timeout()
            .with_uri(url.to_string());
    }

    NativeError::new("network", error.to_string()).with_uri(url.to_string())
}
