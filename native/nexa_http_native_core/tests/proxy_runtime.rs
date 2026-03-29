use nexa_http_native_core::platform::{PlatformRuntimeState, PlatformRuntimeView, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};

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
    let config = CString::new(r#"{"default_headers":{},"timeout_ms":null,"user_agent":null}"#)
        .expect("config json");
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);

    let client_id = runtime.create_client(config.as_ptr());
    assert_ne!(client_id, 0);
    let calls_after_create = calls.load(Ordering::Relaxed);

    let warmup = runtime.execute_binary(client_id, request.as_args());
    NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(warmup);

    switch.store(true, Ordering::Relaxed);
    let after_drift = runtime.execute_binary(client_id, request.as_args());
    NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(after_drift);
    let later_steady_state = runtime.execute_binary(client_id, request.as_args());
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
