use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use std::ffi::CString;

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
    let runtime = NexaHttpRuntime::new(TestCapabilities);
    let config = CString::new(r#"{"default_headers":{},"timeout_ms":null,"user_agent":null}"#)
        .expect("config json");
    let request =
        CString::new(r#"{"method":"GET","url":"http://127.0.0.1:9/ping","headers":{},"timeout_ms":1}"#)
            .expect("request json");

    let client_id = runtime.create_client(config.as_ptr());
    assert_ne!(client_id, 0);

    let initial_builds = runtime.client_build_count_for_test();
    let initial_refreshes = runtime.client_refresh_count_for_test();

    for _ in 0..5 {
        let result = runtime.execute_binary(client_id, request.as_ptr(), std::ptr::null(), 0);
        NexaHttpRuntime::<TestCapabilities>::binary_result_free(result);
    }

    assert_eq!(
        runtime.client_build_count_for_test(),
        initial_builds,
        "steady-state requests should not trigger client rebuilds",
    );
    assert_eq!(
        runtime.client_refresh_count_for_test(),
        initial_refreshes,
        "steady-state requests should not trigger client refresh checks",
    );
}
