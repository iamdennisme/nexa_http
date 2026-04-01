use nexa_http_native_core::platform::{PlatformRuntimeState, PlatformRuntimeView, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::os::raw::c_char;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::LazyLock;
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::mpsc::{self, Sender};
use std::sync::Mutex;
use std::time::Duration;

#[test]
fn proxy_settings_signature_is_stable() {
    let settings = ProxySettings::default();
    assert_eq!(settings.signature_for_test(), "http=|https=|all=|no=");
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
        PlatformRuntimeView::with_proxy_settings(self.generation.load(Ordering::Relaxed), proxy)
    }
}

static NEXT_EXECUTE_ASYNC_REQUEST_ID: AtomicU64 = AtomicU64::new(1);
static EXECUTE_ASYNC_RESULT_SENDERS: LazyLock<Mutex<HashMap<u64, Sender<usize>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

unsafe extern "C" fn capture_execute_async_result(
    _request_id: u64,
    result: *mut nexa_http_native_core::api::ffi::NexaHttpBinaryResult,
) {
    if let Some(sender) = EXECUTE_ASYNC_RESULT_SENDERS.lock().unwrap().remove(&_request_id) {
        let _ = sender.send(result as usize);
    }
}

fn execute_for_test<P: PlatformRuntimeState>(
    runtime: &NexaHttpRuntime<P>,
    client_id: u64,
    request_args: *const nexa_http_native_core::api::ffi::NexaHttpRequestArgs,
) -> *mut nexa_http_native_core::api::ffi::NexaHttpBinaryResult {
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
    result as *mut nexa_http_native_core::api::ffi::NexaHttpBinaryResult
}

#[test]
fn unchanged_generation_keeps_proxy_state_on_the_steady_state_hot_path() {
    let switch = Arc::new(AtomicBool::new(false));
    let calls = Arc::new(AtomicUsize::new(0));
    let generation = Arc::new(AtomicU64::new(0));
    let capabilities = SwitchingProxyCapabilities {
        use_proxy: Arc::clone(&switch),
        proxy_settings_calls: Arc::clone(&calls),
        generation: Arc::clone(&generation),
    };
    let runtime = NexaHttpRuntime::new(capabilities);
    let config = TestClientConfigArgs::new();
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0);
    let calls_after_create = calls.load(Ordering::Relaxed);

    let warmup = execute_for_test(&runtime, client_id, request.as_args());
    NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(warmup);

    switch.store(true, Ordering::Relaxed);
    let after_drift = execute_for_test(&runtime, client_id, request.as_args());
    NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(after_drift);
    let later_steady_state = execute_for_test(&runtime, client_id, request.as_args());
    NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(later_steady_state);

    assert_eq!(
        calls.load(Ordering::Relaxed),
        calls_after_create,
        "snapshot drift alone should not trigger work on the steady-state hot path without a generation change",
    );
}

#[test]
fn changed_generation_is_observable_through_runtime_state() {
    let switch = Arc::new(AtomicBool::new(false));
    let calls = Arc::new(AtomicUsize::new(0));
    let generation = Arc::new(AtomicU64::new(0));
    let capabilities = SwitchingProxyCapabilities {
        use_proxy: Arc::clone(&switch),
        proxy_settings_calls: Arc::clone(&calls),
        generation: Arc::clone(&generation),
    };

    let initial = capabilities.current_platform_state();
    assert_eq!(initial.proxy_generation, 0);
    assert_eq!(initial.platform_features.proxy, ProxySettings::default());

    switch.store(true, Ordering::Relaxed);
    generation.store(1, Ordering::Relaxed);

    let refreshed = capabilities.current_platform_state();
    assert_eq!(refreshed.proxy_generation, 1);
    assert_eq!(
        refreshed.platform_features.proxy.http.as_deref(),
        Some("http://127.0.0.1:8888"),
    );
}

struct TestRequestArgs {
    _method: std::ffi::CString,
    _url: std::ffi::CString,
    args: nexa_http_native_core::api::ffi::NexaHttpRequestArgs,
}

impl TestRequestArgs {
    fn new(method: &str, url: &str, timeout_ms: u64) -> Self {
        let method = std::ffi::CString::new(method).expect("request method");
        let url = std::ffi::CString::new(url).expect("request url");
        let args = nexa_http_native_core::api::ffi::NexaHttpRequestArgs {
            method_ptr: method.as_ptr() as *const c_char,
            method_len: method.as_bytes().len(),
            url_ptr: url.as_ptr() as *const c_char,
            url_len: url.as_bytes().len(),
            headers_ptr: std::ptr::null(),
            headers_len: 0,
            body_ptr: std::ptr::null_mut(),
            body_len: 0,
            body_owned: 0,
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

struct TestClientConfigArgs {
    args: nexa_http_native_core::api::ffi::NexaHttpClientConfigArgs,
}

impl TestClientConfigArgs {
    fn new() -> Self {
        Self {
            args: nexa_http_native_core::api::ffi::NexaHttpClientConfigArgs {
                default_headers_ptr: std::ptr::null(),
                default_headers_len: 0,
                user_agent_ptr: std::ptr::null(),
                user_agent_len: 0,
                timeout_ms: 0,
                has_timeout: 0,
            },
        }
    }

    fn as_args(&self) -> *const nexa_http_native_core::api::ffi::NexaHttpClientConfigArgs {
        &self.args
    }
}
