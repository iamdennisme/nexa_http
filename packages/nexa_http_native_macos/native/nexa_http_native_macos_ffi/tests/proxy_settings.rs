use nexa_http_native_macos_ffi::{current_proxy_settings_for_test, ProxyRuntimeState};

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
fn macos_proxy_runtime_state_tracks_generation_and_latest_snapshot() {
    let initial = current_proxy_settings_for_test(
        false,
        None,
        None,
        true,
        Some("secure-proxy.example.com"),
        Some(8443),
        false,
        None,
        None,
        vec!["localhost".to_string()],
        false,
    );
    let state = ProxyRuntimeState::new(initial.clone());

    let initial_state = state.current_platform_state();
    assert_eq!(initial_state.proxy_generation, 0);
    assert_eq!(initial_state.platform_features.proxy, initial);

    let updated = current_proxy_settings_for_test(
        false,
        None,
        None,
        true,
        Some("secure-proxy.example.com"),
        Some(9443),
        false,
        None,
        None,
        vec!["localhost".to_string()],
        false,
    );

    assert!(state.update_snapshot(updated.clone()));
    let updated_state = state.current_platform_state();
    assert_eq!(updated_state.proxy_generation, 1);
    assert_eq!(updated_state.platform_features.proxy, updated);
}
