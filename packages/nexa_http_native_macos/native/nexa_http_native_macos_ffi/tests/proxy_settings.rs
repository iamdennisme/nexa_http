use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};
use nexa_http_native_core::runtime::ManagedProxyState;
use nexa_http_native_macos_ffi::{MacosProxySource, current_proxy_settings_for_test};

#[test]
fn maps_apple_values_into_proxy_settings() {
    let settings = current_proxy_settings_for_test(
        false,
        None,
        None,
        true,
        Some("secure-proxy.example.com"),
        Some(8443),
        false,
        None,
        None,
        vec!["localhost".to_string(), "*.example.com".to_string()],
        false,
    );
    assert_eq!(
        settings.https.as_deref(),
        Some("http://secure-proxy.example.com:8443/")
    );
}

#[test]
fn macos_exclude_simple_hostnames_maps_to_local_bypass() {
    let settings = current_proxy_settings_for_test(
        false,
        None,
        None,
        false,
        None,
        None,
        false,
        None,
        None,
        Vec::new(),
        true,
    );

    assert!(settings.bypass.contains(&"<local>".to_string()));
}

#[test]
fn macos_sanitizes_quoted_proxy_strings_from_systemconfiguration() {
    let settings = current_proxy_settings_for_test(
        false,
        None,
        None,
        true,
        Some(r#" "secure-proxy.example.com" "#),
        Some(8443),
        false,
        None,
        None,
        vec![r#" "*.example.com" "#.to_string()],
        false,
    );

    assert_eq!(
        settings.https.as_deref(),
        Some("http://secure-proxy.example.com:8443/")
    );
    assert!(settings.bypass.contains(&"*.example.com".to_string()));
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
