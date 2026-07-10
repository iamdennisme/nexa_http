use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};
use nexa_http_native_core::runtime::ManagedProxyState;
use nexa_http_native_ios_ffi::{IosProxySource, current_proxy_settings_for_test};

#[test]
fn ios_adapter_maps_systemconfiguration_values() {
    let settings = current_proxy_settings_for_test(
        true,
        Some("proxy.example.com"),
        Some(3128),
        false,
        None,
        None,
        false,
        None,
        None,
        Vec::new(),
        false,
    );

    assert_eq!(
        settings.http.as_deref(),
        Some("http://proxy.example.com:3128/")
    );
}

#[test]
fn ios_proxy_source_integrates_with_shared_managed_state() {
    let state = ManagedProxyState::new(IosProxySource::new());
    assert_eq!(state.current_platform_state().proxy_generation, 0);
}

#[test]
fn ios_proxy_source_uses_construction_boundary_refresh() {
    let source = IosProxySource::new();
    assert_eq!(source.refresh_mode(), RefreshMode::ConstructionBoundary);
}
