use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;

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
