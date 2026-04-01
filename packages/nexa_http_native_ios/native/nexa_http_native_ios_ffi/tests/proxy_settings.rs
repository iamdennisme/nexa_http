use nexa_http_native_core::runtime::ManagedProxyState;
use nexa_http_native_ios_ffi::{IosProxySource, current_proxy_settings_for_test};

#[test]
fn ios_builds_proxy_settings_from_systemconfiguration_values() {
    let settings = current_proxy_settings_for_test(
        true,
        Some("proxy.example.com"),
        Some(3128),
        false,
        None,
        None,
        true,
        Some("127.0.0.1"),
        Some(1080),
        vec!["example.com".to_string()],
        true,
    );

    assert_eq!(settings.http.as_deref(), Some("http://proxy.example.com:3128/"));
    assert_eq!(settings.https.as_deref(), None);
    assert_eq!(settings.all.as_deref(), Some("socks5://127.0.0.1:1080"));
}

#[test]
fn ios_exclude_simple_hostnames_maps_to_local_bypass() {
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
fn ios_sanitizes_quoted_proxy_strings_from_systemconfiguration() {
    let settings = current_proxy_settings_for_test(
        true,
        Some(r#" "proxy.example.com" "#),
        Some(3128),
        false,
        None,
        None,
        true,
        Some(r#" "127.0.0.1" "#),
        Some(1080),
        vec![r#" "example.com" "#.to_string()],
        true,
    );

    assert_eq!(settings.http.as_deref(), Some("http://proxy.example.com:3128/"));
    assert_eq!(settings.all.as_deref(), Some("socks5://127.0.0.1:1080"));
    assert!(settings.bypass.contains(&"example.com".to_string()));
}

#[test]
fn ios_proxy_source_integrates_with_shared_managed_state() {
    let state = ManagedProxyState::new(IosProxySource::new());
    assert_eq!(state.current_platform_state().proxy_generation, 0);
}
