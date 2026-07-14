use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};
use nexa_http_native_core::runtime::ManagedProxyState;
use nexa_http_native_macos_ffi::{MacosProxySource, current_proxy_settings_for_test};

#[test]
fn macos_adapter_maps_systemconfiguration_values() {
    let settings = current_proxy_settings_for_test(AppleProxySettings {
        http: AppleProxyEntry::default(),
        https: AppleProxyEntry {
            enabled: true,
            host: Some("secure-proxy.example.com".to_string()),
            port: Some(8443),
        },
        socks: AppleProxyEntry::default(),
        exceptions: vec!["localhost".to_string(), "*.example.com".to_string()],
        exclude_simple_hostnames: false,
    });
    assert_eq!(
        settings.https.as_deref(),
        Some("http://secure-proxy.example.com:8443/")
    );
}

#[test]
fn macos_proxy_source_integrates_with_shared_managed_state() {
    let state = ManagedProxyState::new(MacosProxySource::new());
    assert_eq!(state.current_platform_state().proxy_generation, 0);
}

#[test]
fn macos_proxy_source_uses_construction_boundary_refresh() {
    let source = MacosProxySource::new();
    assert_eq!(source.refresh_mode(), RefreshMode::ConstructionBoundary);
}
use nexa_http_native_apple_proxy::{AppleProxyEntry, AppleProxySettings};
