use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

#[derive(Clone, Default)]
struct TestCapabilities;

impl PlatformCapabilities for TestCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        ProxySettings::default()
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
    let runtime = NexaHttpRuntime::new(CountingCapabilities {
        proxy_settings_calls: Arc::clone(&proxy_settings_calls),
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
    let runtime = NexaHttpRuntime::new(CountingCapabilities {
        proxy_settings_calls: Arc::clone(&proxy_settings_calls),
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
}

impl PlatformCapabilities for CountingCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        self.proxy_settings_calls.fetch_add(1, Ordering::Relaxed);
        ProxySettings::default()
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
