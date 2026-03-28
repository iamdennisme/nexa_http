use crate::api::error::{NativeError, NativeHttpError};
use crate::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpHeaderEntry, NexaHttpRequestArgs,
};
use crate::api::request::{NativeHttpClientConfig, NativeHttpHeader, NativeHttpRequest};
use crate::api::response::{NativeHttpOwnedBody, NativeHttpRawResponse};
use crate::platform::{PlatformCapabilities, PlatformFeatures, apply_proxy_strategy};
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
use std::time::{Duration, Instant};
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

const REFRESH_PROBE_INTERVAL: Duration = Duration::from_secs(30);
const REFRESH_FAILURE_BACKOFF: Duration = Duration::from_secs(5);

fn refresh_probe_interval() -> Duration {
    REFRESH_PROBE_INTERVAL
}

fn refresh_failure_backoff() -> Duration {
    REFRESH_FAILURE_BACKOFF
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

        let platform_features = self.inner.capabilities.platform_features();
        let client = match build_client(&config, &platform_features) {
            Ok(client) => client,
            Err(_) => return 0,
        };

        let client_id = self.inner.next_client_id.fetch_add(1, Ordering::Relaxed);
        let entry = ClientEntry::new(
            client,
            config,
            platform_features.signature(),
            Instant::now() + refresh_probe_interval(),
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
    let now = Instant::now();
    let client = {
        let mut clients = inner.clients.lock().unwrap();
        let entry = clients
            .get_mut(&client_id)
            .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
        if entry.refresh_in_progress {
            entry.client.clone()
        } else {
            let probe_due = now >= entry.next_refresh_probe_at;
            if !entry.needs_refresh && !probe_due {
                entry.client.clone()
            } else {
                entry.needs_refresh = true;
                entry.refresh_in_progress = true;
                drop(clients);
                refresh_client_and_clone(&inner, client_id, &request.url)?
            }
        }
    };

    execute_request_with_client_async(&client, request).await
}

fn refresh_client_and_clone<P: PlatformCapabilities>(
    inner: &Arc<NexaHttpRuntimeInner<P>>,
    client_id: u64,
    request_url: &str,
) -> Result<Client, NativeError> {
    let (config, previous_signature) = {
        let clients = inner.clients.lock().unwrap();
        let entry = clients
            .get(&client_id)
            .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
        if !entry.needs_refresh || !entry.refresh_in_progress {
            return Ok(entry.client.clone());
        }
        (
            entry.config.clone(),
            entry.platform_features_signature.clone(),
        )
    };

    let platform_features = inner.capabilities.platform_features();
    let signature = platform_features.signature();
    let rebuilt_client = if signature == previous_signature {
        None
    } else {
        match build_client(&config, &platform_features) {
            Ok(client) => Some(client),
            Err(error) => {
                let mut clients = inner.clients.lock().unwrap();
                let entry = clients
                    .get_mut(&client_id)
                    .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
                if !entry.refresh_in_progress {
                    return Ok(entry.client.clone());
                }
                entry.needs_refresh = false;
                entry.refresh_in_progress = false;
                entry.next_refresh_probe_at = Instant::now() + refresh_failure_backoff();
                return Err(error.with_uri(request_url.to_string()));
            }
        }
    };

    let mut clients = inner.clients.lock().unwrap();
    let entry = clients
        .get_mut(&client_id)
        .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
    if !entry.refresh_in_progress {
        return Ok(entry.client.clone());
    }

    if let Some(client) = rebuilt_client {
        entry.client = client;
        entry.platform_features_signature = signature;
    }
    entry.needs_refresh = false;
    entry.refresh_in_progress = false;
    entry.next_refresh_probe_at = Instant::now() + refresh_probe_interval();
    Ok(entry.client.clone())
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
    use crate::platform::ProxySettings;
    use std::collections::HashMap;
    use std::ffi::CString;
    use std::os::raw::c_char;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

    #[derive(Clone)]
    struct CountingCapabilities {
        proxy_settings_calls: Arc<AtomicUsize>,
    }

    impl PlatformCapabilities for CountingCapabilities {
        fn proxy_settings(&self) -> ProxySettings {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            ProxySettings::default()
        }
    }

    #[derive(Clone)]
    struct SwitchingProxyCapabilities {
        use_proxy: Arc<AtomicBool>,
        proxy_settings_calls: Arc<AtomicUsize>,
    }

    impl PlatformCapabilities for SwitchingProxyCapabilities {
        fn proxy_settings(&self) -> ProxySettings {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            if self.use_proxy.load(Ordering::Relaxed) {
                ProxySettings {
                    http: Some("http://127.0.0.1:8888".to_string()),
                    ..ProxySettings::default()
                }
            } else {
                ProxySettings::default()
            }
        }
    }

    #[derive(Clone)]
    struct InvalidProxyCapabilities {
        use_invalid_proxy: Arc<AtomicBool>,
        proxy_settings_calls: Arc<AtomicUsize>,
    }

    impl PlatformCapabilities for InvalidProxyCapabilities {
        fn proxy_settings(&self) -> ProxySettings {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            if self.use_invalid_proxy.load(Ordering::Relaxed) {
                ProxySettings {
                    http: Some("not a valid proxy url".to_string()),
                    ..ProxySettings::default()
                }
            } else {
                ProxySettings::default()
            }
        }
    }

    #[derive(Clone)]
    struct DelayedProbeCapabilities {
        delay_refresh: Arc<AtomicBool>,
        proxy_settings_calls: Arc<AtomicUsize>,
    }

    impl PlatformCapabilities for DelayedProbeCapabilities {
        fn proxy_settings(&self) -> ProxySettings {
            self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
            if self.delay_refresh.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(50));
            }
            ProxySettings::default()
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

    fn expire_refresh_probe_for_test<P: PlatformCapabilities>(
        runtime: &NexaHttpRuntime<P>,
        client_id: u64,
    ) -> bool {
        let mut clients = runtime.inner.clients.lock().unwrap();
        let Some(entry) = clients.get_mut(&client_id) else {
            return false;
        };
        entry.next_refresh_probe_at = entry
            .next_refresh_probe_at
            .checked_sub(refresh_probe_interval() + Duration::from_millis(1))
            .expect("test probe timestamp should support moving backwards");
        true
    }

    #[test]
    fn expired_refresh_probe_clears_after_one_stable_lookup() {
        let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
        let runtime = NexaHttpRuntime::new(CountingCapabilities {
            proxy_settings_calls: Arc::clone(&proxy_settings_calls),
        });
        let config = client_config_json();
        let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

        assert!(
            expire_refresh_probe_for_test(&runtime, client_id),
            "test should be able to expire the client refresh probe",
        );

        let refreshed = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(refreshed);
        let steady_state = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(steady_state);

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_create + 1,
            "a stable-signature refresh should do one lookup and then return to the fast path",
        );
    }

    #[test]
    fn expired_refresh_probe_rebuilds_once_when_signature_changes() {
        let switch = Arc::new(AtomicBool::new(false));
        let calls = Arc::new(AtomicUsize::new(0));
        let runtime = NexaHttpRuntime::new(SwitchingProxyCapabilities {
            use_proxy: Arc::clone(&switch),
            proxy_settings_calls: Arc::clone(&calls),
        });
        let config = client_config_json();
        let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = calls.load(Ordering::Relaxed);

        let warmup = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(warmup);

        switch.store(true, Ordering::Relaxed);
        assert!(
            expire_refresh_probe_for_test(&runtime, client_id),
            "test should be able to expire the client refresh probe",
        );

        let refreshed = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(refreshed);
        let steady_state = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(steady_state);

        assert_eq!(
            calls.load(Ordering::Relaxed),
            calls_after_create + 1,
            "an explicit refresh marker should trigger one refresh lookup",
        );
    }

    #[test]
    fn failed_refresh_probe_backs_off_before_retrying() {
        let use_invalid_proxy = Arc::new(AtomicBool::new(false));
        let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
        let runtime = NexaHttpRuntime::new(InvalidProxyCapabilities {
            use_invalid_proxy: Arc::clone(&use_invalid_proxy),
            proxy_settings_calls: Arc::clone(&proxy_settings_calls),
        });
        let config = client_config_json();
        let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

        use_invalid_proxy.store(true, Ordering::Relaxed);
        assert!(
            expire_refresh_probe_for_test(&runtime, client_id),
            "test should be able to expire the client refresh probe",
        );

        let failed_refresh = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<InvalidProxyCapabilities>::binary_result_free(failed_refresh);
        let during_backoff = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<InvalidProxyCapabilities>::binary_result_free(during_backoff);

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_create + 1,
            "a failed refresh should not immediately retry on the next request",
        );

        assert!(
            expire_refresh_probe_for_test(&runtime, client_id),
            "test should be able to expire the client refresh probe again",
        );
        let retried_refresh = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<InvalidProxyCapabilities>::binary_result_free(retried_refresh);

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_create + 2,
            "refresh should become eligible again after the next bounded probe window",
        );
    }

    #[test]
    fn expired_refresh_probe_is_single_flight_under_concurrency() {
        let delay_refresh = Arc::new(AtomicBool::new(false));
        let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
        let runtime = NexaHttpRuntime::new(DelayedProbeCapabilities {
            delay_refresh: Arc::clone(&delay_refresh),
            proxy_settings_calls: Arc::clone(&proxy_settings_calls),
        });
        let config = client_config_json();

        let client_id = runtime.create_client(config.as_ptr());
        assert_ne!(client_id, 0);
        let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

        delay_refresh.store(true, Ordering::Relaxed);
        assert!(
            expire_refresh_probe_for_test(&runtime, client_id),
            "test should be able to expire the client refresh probe",
        );

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

        assert_eq!(
            proxy_settings_calls.load(Ordering::Relaxed),
            calls_after_create + 1,
            "only one request should perform the expensive refresh probe work",
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
