use nexa_http_native_core::api::ffi::{
    NexaHttpBinaryResult, NexaHttpClientConfigArgs, NexaHttpHeaderEntry, NexaHttpRequestArgs,
};
use nexa_http_native_core::platform::{PlatformRuntimeState, PlatformRuntimeView, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::os::raw::c_char;
use std::sync::Arc;
use std::sync::LazyLock;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::mpsc::{self, Sender};
use std::time::Duration;

#[derive(Clone, Default)]
struct TestCapabilities;

impl PlatformRuntimeState for TestCapabilities {
    fn proxy_generation(&self) -> u64 {
        0
    }

    fn current_platform_state(&self) -> PlatformRuntimeView {
        PlatformRuntimeView::with_proxy_settings(0, ProxySettings::default())
    }
}

#[test]
fn runtime_creates_a_client_registry() {
    let runtime = NexaHttpRuntime::new(TestCapabilities);
    assert_eq!(runtime.client_count_for_test(), 0);
}

#[test]
fn repeated_requests_reuse_existing_client_without_refresh() {
    let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
    let generation = Arc::new(AtomicU64::new(0));
    let runtime = NexaHttpRuntime::new(CountingCapabilities {
        proxy_settings_calls: Arc::clone(&proxy_settings_calls),
        generation: Arc::clone(&generation),
    });
    let config = TestClientConfigArgs::new();
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0);
    let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

    for _ in 0..5 {
        let result = execute_for_test(&runtime, client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(result);
    }

    assert_eq!(
        proxy_settings_calls.load(Ordering::Relaxed),
        calls_after_create,
        "steady-state requests should not re-read platform features",
    );
}

#[test]
fn steady_state_reuse_survives_multiple_request_batches() {
    let proxy_settings_calls = Arc::new(AtomicUsize::new(0));
    let generation = Arc::new(AtomicU64::new(0));
    let runtime = NexaHttpRuntime::new(CountingCapabilities {
        proxy_settings_calls: Arc::clone(&proxy_settings_calls),
        generation: Arc::clone(&generation),
    });
    let config = TestClientConfigArgs::new();
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0);
    let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

    for _ in 0..3 {
        let result = execute_for_test(&runtime, client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(result);
    }
    for _ in 0..2 {
        let result = execute_for_test(&runtime, client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(result);
    }

    assert_eq!(
        proxy_settings_calls.load(Ordering::Relaxed),
        calls_after_create,
        "steady-state reuse should stay on the fast path across request batches",
    );
}

#[derive(Clone)]
struct CountingCapabilities {
    proxy_settings_calls: Arc<AtomicUsize>,
    generation: Arc<AtomicU64>,
}

impl PlatformRuntimeState for CountingCapabilities {
    fn proxy_generation(&self) -> u64 {
        self.generation.load(Ordering::Relaxed)
    }

    fn current_platform_state(&self) -> PlatformRuntimeView {
        self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
        PlatformRuntimeView::with_proxy_settings(
            self.generation.load(Ordering::Relaxed),
            ProxySettings::default(),
        )
    }
}

struct TestRequestArgs {
    _method: CString,
    _url: CString,
    _header_names: Vec<CString>,
    _header_values: Vec<CString>,
    _headers: Vec<NexaHttpHeaderEntry>,
    args: NexaHttpRequestArgs,
}

impl TestRequestArgs {
    fn new(method: &str, url: &str, timeout_ms: u64) -> Self {
        Self::with_headers(method, url, &[], Some(timeout_ms))
    }

    fn without_timeout(method: &str, url: &str) -> Self {
        Self::with_headers(method, url, &[], None)
    }

    fn with_headers(
        method: &str,
        url: &str,
        headers: &[(&str, &str)],
        timeout_ms: Option<u64>,
    ) -> Self {
        let method = CString::new(method).expect("request method");
        let url = CString::new(url).expect("request url");
        let header_names = headers
            .iter()
            .map(|(name, _)| CString::new(*name).expect("header name"))
            .collect::<Vec<_>>();
        let header_values = headers
            .iter()
            .map(|(_, value)| CString::new(*value).expect("header value"))
            .collect::<Vec<_>>();
        let header_entries = header_names
            .iter()
            .zip(header_values.iter())
            .map(|(name, value)| NexaHttpHeaderEntry {
                name_ptr: name.as_ptr(),
                name_len: name.as_bytes().len(),
                value_ptr: value.as_ptr(),
                value_len: value.as_bytes().len(),
            })
            .collect::<Vec<_>>();
        let args = NexaHttpRequestArgs {
            method_ptr: method.as_ptr() as *const c_char,
            method_len: method.as_bytes().len(),
            url_ptr: url.as_ptr() as *const c_char,
            url_len: url.as_bytes().len(),
            headers_ptr: if header_entries.is_empty() {
                std::ptr::null()
            } else {
                header_entries.as_ptr()
            },
            headers_len: header_entries.len(),
            body_ptr: std::ptr::null_mut(),
            body_len: 0,
            body_owned: 0,
            timeout_ms: timeout_ms.unwrap_or(0),
            has_timeout: u8::from(timeout_ms.is_some()),
        };
        Self {
            _method: method,
            _url: url,
            _header_names: header_names,
            _header_values: header_values,
            _headers: header_entries,
            args,
        }
    }

    fn as_args(&self) -> *const NexaHttpRequestArgs {
        &self.args
    }
}

struct TestClientConfigArgs {
    _header_names: Vec<CString>,
    _header_values: Vec<CString>,
    _headers: Vec<NexaHttpHeaderEntry>,
    _user_agent: Option<CString>,
    args: NexaHttpClientConfigArgs,
}

impl TestClientConfigArgs {
    fn new() -> Self {
        Self::with_defaults(&[], None, None)
    }

    fn with_defaults(
        default_headers: &[(&str, &str)],
        user_agent: Option<&str>,
        timeout_ms: Option<u64>,
    ) -> Self {
        let header_names = default_headers
            .iter()
            .map(|(name, _)| CString::new(*name).expect("default header name"))
            .collect::<Vec<_>>();
        let header_values = default_headers
            .iter()
            .map(|(_, value)| CString::new(*value).expect("default header value"))
            .collect::<Vec<_>>();
        let headers = header_names
            .iter()
            .zip(header_values.iter())
            .map(|(name, value)| NexaHttpHeaderEntry {
                name_ptr: name.as_ptr(),
                name_len: name.as_bytes().len(),
                value_ptr: value.as_ptr(),
                value_len: value.as_bytes().len(),
            })
            .collect::<Vec<_>>();
        let user_agent = user_agent.map(|value| CString::new(value).expect("user agent"));
        let default_headers_ptr = if headers.is_empty() {
            std::ptr::null()
        } else {
            headers.as_ptr()
        };
        let default_headers_len = headers.len();
        let user_agent_ptr = user_agent
            .as_ref()
            .map_or(std::ptr::null(), |value| value.as_ptr());
        let user_agent_len = user_agent
            .as_ref()
            .map_or(0, |value| value.as_bytes().len());
        Self {
            _header_names: header_names,
            _header_values: header_values,
            _headers: headers,
            _user_agent: user_agent,
            args: NexaHttpClientConfigArgs {
                default_headers_ptr,
                default_headers_len,
                user_agent_ptr,
                user_agent_len,
                timeout_ms: timeout_ms.unwrap_or(0),
                has_timeout: u8::from(timeout_ms.is_some()),
            },
        }
    }

    fn as_args(&self) -> *const NexaHttpClientConfigArgs {
        &self.args
    }
}

static EXECUTE_ASYNC_THREAD_SENDER: LazyLock<Mutex<Option<Sender<String>>>> =
    LazyLock::new(|| Mutex::new(None));
static NEXT_EXECUTE_ASYNC_REQUEST_ID: AtomicU64 = AtomicU64::new(1);
static EXECUTE_ASYNC_RESULT_SENDERS: LazyLock<Mutex<HashMap<u64, Sender<usize>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

unsafe extern "C" fn capture_execute_async_thread(
    _request_id: u64,
    result: *mut NexaHttpBinaryResult,
) {
    if let Some(sender) = EXECUTE_ASYNC_THREAD_SENDER.lock().unwrap().as_ref() {
        let thread_name = format!("{:?}", std::thread::current().id());
        let _ = sender.send(thread_name);
    }
    NexaHttpRuntime::<TestCapabilities>::binary_result_free(result);
}

unsafe extern "C" fn capture_execute_async_result(
    _request_id: u64,
    result: *mut NexaHttpBinaryResult,
) {
    if let Some(sender) = EXECUTE_ASYNC_RESULT_SENDERS
        .lock()
        .unwrap()
        .remove(&_request_id)
    {
        let _ = sender.send(result as usize);
    }
}

fn execute_for_test<P: PlatformRuntimeState>(
    runtime: &NexaHttpRuntime<P>,
    client_id: u64,
    request_args: *const NexaHttpRequestArgs,
) -> *mut NexaHttpBinaryResult {
    let (sender, receiver) = mpsc::channel();
    let request_id = NEXT_EXECUTE_ASYNC_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
    EXECUTE_ASYNC_RESULT_SENDERS
        .lock()
        .unwrap()
        .insert(request_id, sender);
    assert_eq!(
        runtime.execute_async(
            client_id,
            request_id,
            request_args,
            Some(capture_execute_async_result),
        ),
        1,
    );
    let result = receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("execute_async should deliver a result");
    result as *mut NexaHttpBinaryResult
}

#[test]
fn invalid_request_error_callback_does_not_run_on_the_caller_thread() {
    let runtime = NexaHttpRuntime::new(TestCapabilities);
    let config = TestClientConfigArgs::new();
    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0);

    let request = nexa_http_native_core::api::ffi::NexaHttpRequestArgs {
        method_ptr: std::ptr::null(),
        method_len: 1,
        url_ptr: std::ptr::null(),
        url_len: 0,
        headers_ptr: std::ptr::null(),
        headers_len: 0,
        body_ptr: std::ptr::null_mut(),
        body_len: 0,
        body_owned: 0,
        timeout_ms: 0,
        has_timeout: 0,
    };

    let (sender, receiver) = mpsc::channel();
    *EXECUTE_ASYNC_THREAD_SENDER.lock().unwrap() = Some(sender);

    let caller_thread = format!("{:?}", std::thread::current().id());
    assert_eq!(
        runtime.execute_async(client_id, 7, &request, Some(capture_execute_async_thread),),
        1,
    );

    let callback_thread = receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("execute_async should deliver an error callback");
    *EXECUTE_ASYNC_THREAD_SENDER.lock().unwrap() = None;

    assert_ne!(
        callback_thread, caller_thread,
        "error callbacks should not re-enter Dart on the originating FFI thread",
    );
}

#[test]
fn client_default_headers_apply_when_request_omits_them() {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind test server");
    let server_addr = listener.local_addr().expect("server addr");
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept request");
        let request = read_http_request(&mut stream);
        sender.send(request).expect("capture request");
        write_http_response(
            &mut stream,
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
        );
    });

    let runtime = NexaHttpRuntime::new(TestCapabilities);
    let config = TestClientConfigArgs::with_defaults(&[("x-client", "nexa")], None, None);
    let request =
        TestRequestArgs::without_timeout("GET", &format!("http://{server_addr}/default-header"));

    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0, "client creation should succeed");

    let result = execute_for_test(&runtime, client_id, request.as_args());
    let request_text = receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("server should capture request");

    unsafe {
        assert_eq!((*result).is_success, 1, "request should succeed");
        NexaHttpRuntime::<TestCapabilities>::binary_result_free(result);
    }
    assert!(
        request_text
            .to_ascii_lowercase()
            .contains("\r\nx-client: nexa\r\n"),
        "default headers from the client lease should reach native execution",
    );
}

#[test]
fn request_headers_override_client_defaults() {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind test server");
    let server_addr = listener.local_addr().expect("server addr");
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept request");
        let request = read_http_request(&mut stream);
        sender.send(request).expect("capture request");
        write_http_response(
            &mut stream,
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
        );
    });

    let runtime = NexaHttpRuntime::new(TestCapabilities);
    let config = TestClientConfigArgs::with_defaults(&[("x-client", "nexa")], None, None);
    let request = TestRequestArgs::with_headers(
        "GET",
        &format!("http://{server_addr}/override-header"),
        &[("x-client", "override")],
        None,
    );

    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0, "client creation should succeed");

    let result = execute_for_test(&runtime, client_id, request.as_args());
    let request_text = receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("server should capture request");

    unsafe {
        assert_eq!((*result).is_success, 1, "request should succeed");
        NexaHttpRuntime::<TestCapabilities>::binary_result_free(result);
    }
    let normalized = request_text.to_ascii_lowercase();
    assert!(
        normalized.contains("\r\nx-client: override\r\n"),
        "request-specific headers should override the client lease defaults",
    );
    assert!(
        !normalized.contains("\r\nx-client: nexa\r\n"),
        "the overridden default header should not be sent alongside the request override",
    );
}

#[test]
fn request_timeout_override_wins_over_client_default_timeout() {
    let slow_server = TcpListener::bind("127.0.0.1:0").expect("bind slow server");
    let slow_addr = slow_server.local_addr().expect("slow server addr");
    std::thread::spawn(move || {
        let (mut stream, _) = slow_server.accept().expect("accept request");
        let _request = read_http_request(&mut stream);
        std::thread::sleep(Duration::from_millis(60));
        write_http_response(
            &mut stream,
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
        );
    });

    let timeout_runtime = NexaHttpRuntime::new(TestCapabilities);
    let timeout_config = TestClientConfigArgs::with_defaults(&[], None, Some(20));
    let timeout_request =
        TestRequestArgs::without_timeout("GET", &format!("http://{slow_addr}/client-timeout"));

    let timeout_client_id = timeout_runtime.create_client(timeout_config.as_args());
    assert_ne!(timeout_client_id, 0, "client creation should succeed");

    let timeout_result = execute_for_test(
        &timeout_runtime,
        timeout_client_id,
        timeout_request.as_args(),
    );
    let timeout_error = unsafe {
        assert_eq!(
            (*timeout_result).is_success,
            0,
            "client default timeout should fire"
        );
        CStr::from_ptr((*timeout_result).error_json)
            .to_string_lossy()
            .into_owned()
    };
    NexaHttpRuntime::<TestCapabilities>::binary_result_free(timeout_result);
    assert!(
        timeout_error.contains("\"code\":\"timeout\""),
        "client default timeout should apply when request timeout is unset",
    );

    let override_server = TcpListener::bind("127.0.0.1:0").expect("bind override server");
    let override_addr = override_server.local_addr().expect("override server addr");
    std::thread::spawn(move || {
        let (mut stream, _) = override_server.accept().expect("accept request");
        let _request = read_http_request(&mut stream);
        std::thread::sleep(Duration::from_millis(60));
        write_http_response(
            &mut stream,
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
        );
    });

    let override_runtime = NexaHttpRuntime::new(TestCapabilities);
    let override_config = TestClientConfigArgs::with_defaults(&[], None, Some(20));
    let override_request = TestRequestArgs::with_headers(
        "GET",
        &format!("http://{override_addr}/request-timeout"),
        &[],
        Some(200),
    );

    let override_client_id = override_runtime.create_client(override_config.as_args());
    assert_ne!(override_client_id, 0, "client creation should succeed");

    let override_result = execute_for_test(
        &override_runtime,
        override_client_id,
        override_request.as_args(),
    );
    unsafe {
        assert_eq!(
            (*override_result).is_success,
            1,
            "request timeout override should win over the client default timeout",
        );
        NexaHttpRuntime::<TestCapabilities>::binary_result_free(override_result);
    }
}

fn read_http_request(stream: &mut TcpStream) -> String {
    let mut buffer = [0u8; 4096];
    let mut request = Vec::new();
    loop {
        let read = stream.read(&mut buffer).expect("read request bytes");
        if read == 0 {
            break;
        }
        request.extend_from_slice(&buffer[..read]);
        if request.windows(4).any(|window| window == b"\r\n\r\n") {
            break;
        }
    }
    String::from_utf8(request).expect("request should be utf8-compatible")
}

fn write_http_response(stream: &mut TcpStream, response: &str) {
    stream
        .write_all(response.as_bytes())
        .expect("write response bytes");
    stream.flush().expect("flush response bytes");
}
