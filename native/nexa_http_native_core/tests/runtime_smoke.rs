use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::ffi::CString;
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
    let request =
        CString::new(r#"{"method":"GET","url":"http://127.0.0.1:9/ping","headers":{},"timeout_ms":1}"#)
            .expect("request json");

    let client_id = runtime.create_client(config.as_ptr());
    assert_ne!(client_id, 0);
    let calls_after_create = proxy_settings_calls.load(Ordering::Relaxed);

    for _ in 0..5 {
        let result = runtime.execute_binary(client_id, request.as_ptr(), std::ptr::null(), 0);
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(result);
    }

    assert_eq!(
        proxy_settings_calls.load(Ordering::Relaxed),
        calls_after_create,
        "steady-state requests should not re-read platform features",
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
