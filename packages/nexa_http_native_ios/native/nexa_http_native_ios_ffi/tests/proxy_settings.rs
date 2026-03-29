use nexa_http_native_ios_ffi::{current_proxy_settings_for_test, ProxyRuntimeState};

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
fn ios_proxy_runtime_state_tracks_generation_and_latest_snapshot() {
    let initial = current_proxy_settings_for_test(
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
    let state = ProxyRuntimeState::new(initial.clone());

    let initial_state = state.current_platform_state();
    assert_eq!(initial_state.proxy_generation, 0);
    assert_eq!(initial_state.platform_features.proxy, initial);

    let updated = current_proxy_settings_for_test(
        true,
        Some("proxy.example.com"),
        Some(4128),
        false,
        None,
        None,
        false,
        None,
        None,
        Vec::new(),
        false,
    );

    assert!(state.update_snapshot(updated.clone()));
    let updated_state = state.current_platform_state();
    assert_eq!(updated_state.proxy_generation, 1);
    assert_eq!(updated_state.platform_features.proxy, updated);
}
