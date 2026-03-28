use nexa_http_native_core::platform::PlatformCapabilities;
use nexa_http_native_core::platform::ProxySettings;
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

#[test]
fn proxy_settings_signature_is_stable() {
    let settings = ProxySettings::default();
    assert_eq!(settings.signature_for_test(), "http=|https=|all=|no=");
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

#[test]
fn proxy_signature_change_triggers_refresh_once() {
    let switch = Arc::new(AtomicBool::new(false));
    let calls = Arc::new(AtomicUsize::new(0));
    let capabilities = SwitchingProxyCapabilities {
        use_proxy: Arc::clone(&switch),
        proxy_settings_calls: Arc::clone(&calls),
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

    let refreshed = runtime.execute_binary(client_id, request.as_args());
    NexaHttpRuntime::<SwitchingProxyCapabilities>::binary_result_free(refreshed);

    assert_eq!(
        calls.load(Ordering::Relaxed),
        calls_after_create + 1,
        "signature drift should trigger one refresh lookup",
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
