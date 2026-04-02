use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};
use nexa_http_native_windows_ffi::{WindowsProxySource, current_proxy_settings_for_test};

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
fn windows_empty_proxy_server_produces_empty_settings() {
    let settings = current_proxy_settings_for_test("", None);
    assert_eq!(settings.http, None);
    assert_eq!(settings.https, None);
    assert_eq!(settings.all, None);
}

#[test]
fn windows_proxy_source_uses_construction_boundary_refresh() {
    let source = WindowsProxySource::new();
    assert_eq!(source.refresh_mode(), RefreshMode::ConstructionBoundary);
}
