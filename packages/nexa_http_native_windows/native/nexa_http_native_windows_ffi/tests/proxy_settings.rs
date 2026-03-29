use nexa_http_native_windows_ffi::{current_proxy_settings_for_test, ProxyRuntimeState};

#[test]
fn windows_parses_split_proxy_server_entries() {
    let settings = current_proxy_settings_for_test(
        "http=127.0.0.1:8080;https=127.0.0.1:8443;socks=127.0.0.1:1080",
        Some("localhost;127.0.0.1;*.example.com"),
    );

    assert_eq!(settings.http.as_deref(), Some("http://127.0.0.1:8080/"));
    assert_eq!(settings.https.as_deref(), Some("http://127.0.0.1:8443/"));
    assert_eq!(settings.all.as_deref(), Some("socks5://127.0.0.1:1080"));
    assert!(settings.bypass.contains(&"localhost".to_string()));
}

#[test]
fn windows_proxy_runtime_state_tracks_generation_and_latest_snapshot() {
    let initial = current_proxy_settings_for_test(
        "http=127.0.0.1:8080;https=127.0.0.1:8443;socks=127.0.0.1:1080",
        Some("localhost;127.0.0.1;*.example.com"),
    );
    let state = ProxyRuntimeState::new(initial.clone());

    let initial_state = state.current_platform_state();
    assert_eq!(initial_state.proxy_generation, 0);
    assert_eq!(initial_state.platform_features.proxy, initial);

    let updated = current_proxy_settings_for_test(
        "http=127.0.0.1:9080;https=127.0.0.1:9443;socks=127.0.0.1:1080",
        Some("localhost;127.0.0.1;*.example.com"),
    );

    assert!(state.update_snapshot(updated.clone()));
    let updated_state = state.current_platform_state();
    assert_eq!(updated_state.proxy_generation, 1);
    assert_eq!(updated_state.platform_features.proxy, updated);
}
