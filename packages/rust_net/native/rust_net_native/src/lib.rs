use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::ptr::null_mut;
use std::slice::from_raw_parts;
use std::str::FromStr;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use once_cell::sync::Lazy;
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::{Client, ClientBuilder, Method};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use tokio::runtime::{Builder as RuntimeBuilder, Runtime};
use tokio::sync::Semaphore;

mod platform;
mod proxy_strategy;

static CLIENTS: Lazy<Mutex<HashMap<u64, ClientEntry>>> = Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT_CLIENT_ID: AtomicU64 = AtomicU64::new(1);
static RUNTIME: Lazy<Runtime> = Lazy::new(build_runtime);
static REQUEST_LIMITER: Lazy<Arc<Semaphore>> =
    Lazy::new(|| Arc::new(Semaphore::new(default_max_inflight_requests())));

#[derive(Clone)]
struct ClientEntry {
    client: Client,
    config: NativeHttpClientConfig,
    proxy_signature: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpClientConfig {
    default_headers: HashMap<String, String>,
    timeout_ms: Option<u64>,
    user_agent: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpRequestMetadata {
    method: String,
    url: String,
    headers: HashMap<String, String>,
    timeout_ms: Option<u64>,
}

#[derive(Debug, Clone)]
struct NativeHttpRequest {
    method: String,
    url: String,
    headers: HashMap<String, String>,
    body: Vec<u8>,
    timeout_ms: Option<u64>,
}

#[derive(Debug, Clone)]
struct NativeHttpRawResponse {
    status_code: u16,
    headers: HashMap<String, Vec<String>>,
    body: Vec<u8>,
    final_url: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
struct NativeHttpError {
    code: String,
    message: String,
    status_code: Option<u16>,
    is_timeout: bool,
    uri: Option<String>,
    details: Option<HashMap<String, String>>,
}

#[repr(C)]
pub struct RustNetBinaryResult {
    is_success: u8,
    status_code: u16,
    headers_json: *mut c_char,
    final_url: *mut c_char,
    body_ptr: *mut u8,
    body_len: usize,
    error_json: *mut c_char,
}

type RustNetExecuteCallback = Option<unsafe extern "C" fn(u64, *mut RustNetBinaryResult)>;

#[derive(Debug)]
struct NativeError {
    code: &'static str,
    message: String,
    status_code: Option<u16>,
    is_timeout: bool,
    uri: Option<String>,
    details: Option<HashMap<String, String>>,
}

impl NativeError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            status_code: None,
            is_timeout: false,
            uri: None,
            details: None,
        }
    }

    fn with_uri(mut self, uri: impl Into<String>) -> Self {
        self.uri = Some(uri.into());
        self
    }

    fn with_timeout(mut self) -> Self {
        self.is_timeout = true;
        self
    }

    fn with_details(mut self, details: HashMap<String, String>) -> Self {
        self.details = Some(details);
        self
    }

    fn into_http_error(self) -> NativeHttpError {
        NativeHttpError {
            code: self.code.to_string(),
            message: self.message,
            status_code: self.status_code,
            is_timeout: self.is_timeout,
            uri: self.uri,
            details: self.details,
        }
    }
}

fn build_runtime() -> Runtime {
    RuntimeBuilder::new_multi_thread()
        .worker_threads(default_runtime_worker_threads())
        .enable_all()
        .build()
        .expect("failed to build tokio runtime")
}

fn default_runtime_worker_threads() -> usize {
    std::thread::available_parallelism()
        .map(|value| value.get().clamp(2, 8))
        .unwrap_or(4)
}

fn default_max_inflight_requests() -> usize {
    let parallelism = std::thread::available_parallelism()
        .map(|value| value.get())
        .unwrap_or(4);
    (parallelism * 32).clamp(64, 512)
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_create(config_json: *const c_char) -> u64 {
    let config = match read_json::<NativeHttpClientConfig>(config_json) {
        Ok(config) => config,
        Err(_) => return 0,
    };

    let platform_features = platform::current_platform_features();
    let platform_features = proxy_strategy::merge_env_fallback(platform_features);

    let (client, proxy_snapshot) = {
        let snapshot = proxy_strategy::current_proxy_snapshot();
        let client = match build_client(&config, &snapshot) {
            Ok(client) => client,
            Err(_) => return 0,
        };
        (client, snapshot)
    };

    let client_id = NEXT_CLIENT_ID.fetch_add(1, Ordering::Relaxed);
    let entry = ClientEntry {
        client,
        config,
        proxy_signature: proxy_snapshot.signature(),
    };
    CLIENTS.lock().unwrap().insert(client_id, entry);
    client_id
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_execute_async(
    client_id: u64,
    request_id: u64,
    request_json: *const c_char,
    body_ptr: *const u8,
    body_len: usize,
    callback: RustNetExecuteCallback,
) -> u8 {
    let Some(callback) = callback else {
        return 0;
    };

    let request = match read_request(request_json, body_ptr, body_len) {
        Ok(request) => request,
        Err(error) => {
            let result = build_binary_error_result(error.into_http_error());
            unsafe {
                callback(request_id, Box::into_raw(Box::new(result)));
            }
            return 1;
        }
    };

    RUNTIME.spawn(async move {
        let result = execute_request_with_limit(client_id, request)
            .await
            .map(build_binary_success_result)
            .unwrap_or_else(|error| build_binary_error_result(error.into_http_error()));

        unsafe {
            callback(request_id, Box::into_raw(Box::new(result)));
        }
    });

    1
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_execute_binary(
    client_id: u64,
    request_json: *const c_char,
    body_ptr: *const u8,
    body_len: usize,
) -> *mut RustNetBinaryResult {
    let result = match read_request(request_json, body_ptr, body_len) {
        Ok(request) => RUNTIME
            .block_on(execute_request_with_limit(client_id, request))
            .map(build_binary_success_result)
            .unwrap_or_else(|error| build_binary_error_result(error.into_http_error())),
        Err(error) => build_binary_error_result(error.into_http_error()),
    };

    Box::into_raw(Box::new(result))
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_client_close(client_id: u64) {
    CLIENTS.lock().unwrap().remove(&client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_net_binary_result_free(value: *mut RustNetBinaryResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let result = Box::from_raw(value);
        if !result.headers_json.is_null() {
            drop(CString::from_raw(result.headers_json));
        }
        if !result.final_url.is_null() {
            drop(CString::from_raw(result.final_url));
        }
        if !result.error_json.is_null() {
            drop(CString::from_raw(result.error_json));
        }
        if !result.body_ptr.is_null() && result.body_len > 0 {
            drop(Vec::from_raw_parts(
                result.body_ptr,
                result.body_len,
                result.body_len,
            ));
        }
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
    request_json: *const c_char,
    body_ptr: *const u8,
    body_len: usize,
) -> Result<NativeHttpRequest, NativeError> {
    let metadata = read_json::<NativeHttpRequestMetadata>(request_json)?;
    let body = if body_len == 0 {
        Vec::new()
    } else if body_ptr.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null body pointer when body_len > 0.",
        ));
    } else {
        unsafe { from_raw_parts(body_ptr, body_len) }.to_vec()
    };

    Ok(NativeHttpRequest {
        method: metadata.method,
        url: metadata.url,
        headers: metadata.headers,
        body,
        timeout_ms: metadata.timeout_ms,
    })
}

fn build_client(
    config: &NativeHttpClientConfig,
    proxy_snapshot: &proxy_strategy::ProxySnapshot,
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
    builder = proxy_strategy::apply_proxy_strategy(builder, proxy_snapshot)
        .map_err(|error| NativeError::new("invalid_proxy", error))?;

    builder
        .build()
        .map_err(|error| NativeError::new("invalid_config", error.to_string()))
}

async fn execute_request_with_limit(
    client_id: u64,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let _permit = REQUEST_LIMITER
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| NativeError::new("internal", "Request limiter unexpectedly closed."))?;

    execute_request(client_id, request).await
}

async fn execute_request(
    client_id: u64,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let client = {
        let mut clients = CLIENTS.lock().unwrap();
        let entry = clients
            .get_mut(&client_id)
            .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
        let proxy_snapshot = proxy_strategy::current_proxy_snapshot();
        let signature = proxy_snapshot.signature();
        if signature != entry.proxy_signature {
            entry.client = build_client(&entry.config, &proxy_snapshot)
                .map_err(|error| error.with_uri(request.url.clone()))?;
            entry.proxy_signature = signature;
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

    let mut headers = HashMap::<String, Vec<String>>::new();
    for (name, value) in response.headers() {
        let value_string = value.to_str().unwrap_or_default().to_string();
        headers
            .entry(name.to_string())
            .or_default()
            .push(value_string);
    }

    let final_url = Some(response.url().to_string());
    let body = response
        .bytes()
        .await
        .map_err(|error| map_reqwest_error(error, &url))?;

    Ok(NativeHttpRawResponse {
        status_code,
        headers,
        body: body.to_vec(),
        final_url,
    })
}

fn build_binary_success_result(response: NativeHttpRawResponse) -> RustNetBinaryResult {
    let headers_json = match serde_json::to_string(&response.headers)
        .ok()
        .and_then(|json| CString::new(json).ok())
    {
        Some(value) => value.into_raw(),
        None => {
            return build_binary_error_result(NativeHttpError {
                code: "serialization".to_string(),
                message: "Failed to encode response headers.".to_string(),
                status_code: None,
                is_timeout: false,
                uri: None,
                details: None,
            });
        }
    };

    let final_url = match response.final_url {
        Some(value) => match CString::new(value) {
            Ok(value) => value.into_raw(),
            Err(_) => {
                unsafe {
                    drop(CString::from_raw(headers_json));
                }
                return build_binary_error_result(NativeHttpError {
                    code: "serialization".to_string(),
                    message: "Failed to encode final URL.".to_string(),
                    status_code: None,
                    is_timeout: false,
                    uri: None,
                    details: None,
                });
            }
        },
        None => null_mut(),
    };

    let mut body = response.body;
    let body_len = body.len();
    let body_ptr = if body_len == 0 {
        null_mut()
    } else {
        let ptr = body.as_mut_ptr();
        std::mem::forget(body);
        ptr
    };

    RustNetBinaryResult {
        is_success: 1,
        status_code: response.status_code,
        headers_json,
        final_url,
        body_ptr,
        body_len,
        error_json: null_mut(),
    }
}

fn build_binary_error_result(error: NativeHttpError) -> RustNetBinaryResult {
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

    RustNetBinaryResult {
        is_success: 0,
        status_code: 0,
        headers_json: null_mut(),
        final_url: null_mut(),
        body_ptr: null_mut(),
        body_len: 0,
        error_json,
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

#[cfg(test)]
mod tests {
    use super::*;
    use httpmock::Method::GET;
    use httpmock::MockServer;
    use std::env;
    use std::sync::Mutex;

    static PROXY_ENV_MUTEX: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    #[test]
    fn executes_http_requests_and_collects_response_data() {
        let server = MockServer::start();
        let mock = server.mock(|when, then| {
            when.method(GET).path("/hello");
            then.status(200)
                .header("content-type", "text/plain")
                .body("world");
        });

        let snapshot = proxy_strategy::current_proxy_snapshot();
        let client = build_client(&NativeHttpClientConfig::default(), &snapshot).unwrap();
        let response = execute_request_with_client(
            &client,
            NativeHttpRequest {
                method: "GET".to_string(),
                url: server.url("/hello"),
                headers: HashMap::new(),
                body: Vec::new(),
                timeout_ms: None,
            },
        )
        .unwrap();

        mock.assert();
        assert_eq!(response.status_code, 200);
        assert_eq!(response.body, b"world");
        assert_eq!(
            response.headers.get("content-type"),
            Some(&vec!["text/plain".to_string()])
        );
    }

    #[test]
    fn builds_binary_success_results_without_base64() {
        let result = build_binary_success_result(NativeHttpRawResponse {
            status_code: 200,
            headers: HashMap::from([("content-type".to_string(), vec!["image/jpeg".to_string()])]),
            body: b"raw-bytes".to_vec(),
            final_url: Some("https://example.com/image.jpg".to_string()),
        });

        assert_eq!(result.is_success, 1);
        unsafe {
            let headers = serde_json::from_str::<HashMap<String, Vec<String>>>(
                CStr::from_ptr(result.headers_json).to_str().unwrap(),
            )
            .unwrap();
            assert_eq!(
                headers.get("content-type"),
                Some(&vec!["image/jpeg".to_string()])
            );
            let body = std::slice::from_raw_parts(result.body_ptr, result.body_len);
            assert_eq!(body, b"raw-bytes");
        }

        let result_ptr = Box::into_raw(Box::new(result));
        rust_net_binary_result_free(result_ptr);
    }

    #[test]
    fn marks_timeout_errors() {
        let server = MockServer::start();
        server.mock(|when, then| {
            when.method(GET).path("/slow");
            then.status(200)
                .delay(Duration::from_millis(50))
                .body("slow");
        });

        let snapshot = proxy_strategy::current_proxy_snapshot();
        let client = build_client(&NativeHttpClientConfig::default(), &snapshot).unwrap();
        let error = execute_request_with_client(
            &client,
            NativeHttpRequest {
                method: "GET".to_string(),
                url: server.url("/slow"),
                headers: HashMap::new(),
                body: Vec::new(),
                timeout_ms: Some(5),
            },
        )
        .unwrap_err();

        assert_eq!(error.code, "timeout");
        assert!(error.is_timeout);
    }

    #[test]
    fn rejects_unknown_client_handles() {
        let error = RUNTIME
            .block_on(execute_request(
                u64::MAX,
                NativeHttpRequest {
                    method: "GET".to_string(),
                    url: "https://example.com".to_string(),
                    headers: HashMap::new(),
                    body: Vec::new(),
                    timeout_ms: None,
                },
            ))
            .unwrap_err();

        assert_eq!(error.code, "invalid_client");
    }

    #[test]
    fn rejects_invalid_http_methods() {
        let snapshot = proxy_strategy::current_proxy_snapshot();
        let client = build_client(&NativeHttpClientConfig::default(), &snapshot).unwrap();
        let error = execute_request_with_client(
            &client,
            NativeHttpRequest {
                method: "NOT VALID".to_string(),
                url: "https://example.com".to_string(),
                headers: HashMap::new(),
                body: Vec::new(),
                timeout_ms: None,
            },
        )
        .unwrap_err();

        assert_eq!(error.code, "invalid_request");
    }

    #[test]
    fn rebuilds_client_when_proxy_snapshot_changes() {
        let _guard = PROXY_ENV_MUTEX.lock().unwrap();
        clear_proxy_env();

        let server = MockServer::start();
        let mock = server.mock(|when, then| {
            when.method(GET).path("/rebuild");
            then.status(200).body("rebuilt");
        });

        let config = NativeHttpClientConfig::default();
        let initial_snapshot = proxy_strategy::current_proxy_snapshot();
        let client = build_client(&config, &initial_snapshot).unwrap();
        let client_id = NEXT_CLIENT_ID.fetch_add(1, Ordering::Relaxed);

        CLIENTS.lock().unwrap().insert(
            client_id,
            ClientEntry {
                client,
                config: config.clone(),
                proxy_signature: initial_snapshot.signature(),
            },
        );

        unsafe {
            env::set_var("NO_PROXY", "example-test.invalid");
        }
        let expected_signature = proxy_strategy::current_proxy_snapshot().signature();

        let response = RUNTIME
            .block_on(execute_request(
                client_id,
                NativeHttpRequest {
                    method: "GET".to_string(),
                    url: server.url("/rebuild"),
                    headers: HashMap::new(),
                    body: Vec::new(),
                    timeout_ms: None,
                },
            ))
            .unwrap();

        let actual_signature = CLIENTS
            .lock()
            .unwrap()
            .get(&client_id)
            .map(|entry| entry.proxy_signature.clone());
        CLIENTS.lock().unwrap().remove(&client_id);
        clear_proxy_env();

        mock.assert();
        assert_eq!(response.status_code, 200);
        assert_eq!(
            actual_signature.as_deref(),
            Some(expected_signature.as_str())
        );
        assert_ne!(initial_snapshot.signature(), expected_signature);
    }

    fn execute_request_with_client(
        client: &Client,
        request: NativeHttpRequest,
    ) -> Result<NativeHttpRawResponse, NativeError> {
        RUNTIME.block_on(execute_request_with_client_async(client, request))
    }

    fn clear_proxy_env() {
        for key in [
            "HTTP_PROXY",
            "http_proxy",
            "HTTPS_PROXY",
            "https_proxy",
            "ALL_PROXY",
            "all_proxy",
            "NO_PROXY",
            "no_proxy",
            "SOCKS_PROXY",
            "socks_proxy",
        ] {
            unsafe {
                env::remove_var(key);
            }
        }
    }
}
