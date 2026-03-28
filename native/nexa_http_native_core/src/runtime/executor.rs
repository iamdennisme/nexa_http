use crate::api::error::{NativeError, NativeHttpError};
use crate::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpHeaderEntry, NexaHttpRequestArgs,
    record_test_binary_result_free,
};
use crate::api::request::{NativeHttpClientConfig, NativeHttpHeader, NativeHttpRequest};
use crate::api::response::{NativeHttpOwnedBody, NativeHttpRawResponse};
use crate::platform::{
    PlatformCapabilities, PlatformFeatures, apply_proxy_strategy, merge_env_fallback,
};
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

pub struct NexaHttpRuntime<P: PlatformCapabilities> {
    inner: Arc<NexaHttpRuntimeInner<P>>,
}

struct NexaHttpRuntimeInner<P: PlatformCapabilities> {
    capabilities: P,
    clients: Mutex<HashMap<u64, ClientEntry>>,
    next_client_id: AtomicU64,
    tokio: Runtime,
    request_limiter: Arc<Semaphore>,
}

impl<P: PlatformCapabilities> NexaHttpRuntime<P> {
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

        let platform_features = current_platform_features(&self.inner);
        let client = match build_client(&config, &platform_features) {
            Ok(client) => client,
            Err(_) => return 0,
        };

        let client_id = self.inner.next_client_id.fetch_add(1, Ordering::Relaxed);
        let entry = ClientEntry {
            client,
            config,
            platform_features_signature: platform_features.signature(),
        };
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
                let result = build_binary_error_result(error.into_http_error());
                unsafe {
                    callback(request_id, Box::into_raw(Box::new(result)));
                }
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
            let mut result = Box::from_raw(value);
            if !record_test_binary_result_free(value) {
                return;
            }
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
}

fn current_platform_features<P: PlatformCapabilities>(
    inner: &NexaHttpRuntimeInner<P>,
) -> PlatformFeatures {
    let platform_features =
        PlatformFeatures::from_proxy_settings(inner.capabilities.proxy_settings());
    merge_env_fallback(platform_features)
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

async fn execute_request_with_limit<P: PlatformCapabilities>(
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

async fn execute_request<P: PlatformCapabilities>(
    inner: Arc<NexaHttpRuntimeInner<P>>,
    client_id: u64,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let client = {
        let mut clients = inner.clients.lock().unwrap();
        let entry = clients
            .get_mut(&client_id)
            .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
        let platform_features = current_platform_features(&inner);
        let signature = platform_features.signature();
        if signature != entry.platform_features_signature {
            entry.client = build_client(&entry.config, &platform_features)
                .map_err(|error| error.with_uri(request.url.clone()))?;
            entry.platform_features_signature = signature;
        }
        entry.client.clone()
    };

    execute_request_with_client_async(&client, request).await
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
