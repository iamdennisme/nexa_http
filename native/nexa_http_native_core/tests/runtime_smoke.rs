use nexa_http_native_core::platform::{PlatformRuntimeState, PlatformRuntimeView, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::ffi::CString;
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
    let config = CString::new(r#"{"default_headers":{},"timeout_ms":null,"user_agent":null}"#)
        .expect("config json");
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

    let client_id = runtime.create_client(config.as_ptr());
    assert_ne!(client_id, 0);
    let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

    for _ in 0..5 {
        let result = runtime.execute_binary(client_id, request.as_args());
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
    let config = CString::new(r#"{"default_headers":{},"timeout_ms":null,"user_agent":null}"#)
        .expect("config json");
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

    let client_id = runtime.create_client(config.as_ptr());
    assert_ne!(client_id, 0);
    let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

    for _ in 0..3 {
        let result = runtime.execute_binary(client_id, request.as_args());
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(result);
    }
    for _ in 0..2 {
        let result = runtime.execute_binary(client_id, request.as_args());
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
    args: nexa_http_native_core::api::ffi::NexaHttpRequestArgs,
}

impl TestRequestArgs {
    fn new(method: &str, url: &str, timeout_ms: u64) -> Self {
        let method = CString::new(method).expect("request method");
        let url = CString::new(url).expect("request url");
        let args = nexa_http_native_core::api::ffi::NexaHttpRequestArgs {
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

    fn as_args(&self) -> *const nexa_http_native_core::api::ffi::NexaHttpRequestArgs {
        &self.args
    }
}

static EXECUTE_ASYNC_THREAD_SENDER: LazyLock<Mutex<Option<Sender<String>>>> =
    LazyLock::new(|| Mutex::new(None));

unsafe extern "C" fn capture_execute_async_thread(
    _request_id: u64,
    result: *mut nexa_http_native_core::api::ffi::NexaHttpBinaryResult,
) {
    if let Some(sender) = EXECUTE_ASYNC_THREAD_SENDER.lock().unwrap().as_ref() {
        let thread_name = format!("{:?}", std::thread::current().id());
        let _ = sender.send(thread_name);
    }
    NexaHttpRuntime::<TestCapabilities>::binary_result_free(result);
}

#[test]
fn invalid_request_error_callback_does_not_run_on_the_caller_thread() {
    let runtime = NexaHttpRuntime::new(TestCapabilities);
    let config = CString::new(r#"{"default_headers":{},"timeout_ms":null,"user_agent":null}"#)
        .expect("config json");
    let client_id = runtime.create_client(config.as_ptr());
    assert_ne!(client_id, 0);

    let request = nexa_http_native_core::api::ffi::NexaHttpRequestArgs {
        method_ptr: std::ptr::null(),
        method_len: 1,
        url_ptr: std::ptr::null(),
        url_len: 0,
        headers_ptr: std::ptr::null(),
        headers_len: 0,
        body_ptr: std::ptr::null(),
        body_len: 0,
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
