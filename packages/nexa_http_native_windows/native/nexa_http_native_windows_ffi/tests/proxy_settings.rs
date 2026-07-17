use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};
use nexa_http_native_windows_ffi::{WindowsProxySource, current_proxy_settings_for_test};

#[path = "../../../../../native/nexa_http_native_core/tests/fixtures/proxy_normalization_cases.rs"]
mod fixtures;

#[test]
fn windows_parses_split_proxy_server_entries() {
    let settings = current_proxy_settings_for_test(
        "http=proxy.example.com:8080;https=secure.example.com:8443;socks=127.0.0.1:1080",
        Some("localhost;example.com"),
    );

    assert_eq!(
        settings.http.as_deref(),
        Some("http://proxy.example.com:8080/")
    );
    assert_eq!(
        settings.https.as_deref(),
        Some("http://secure.example.com:8443/")
    );
    assert_eq!(settings.all.as_deref(), Some("socks5://127.0.0.1:1080"));
    let expected_bypass = fixtures::VALID_BYPASS
        .iter()
        .map(|item| (*item).to_string())
        .collect::<Vec<_>>();
    assert_eq!(settings.bypass, expected_bypass);
}

#[test]
fn windows_empty_proxy_server_produces_empty_settings() {
    let settings = current_proxy_settings_for_test("", None);
    assert_eq!(settings.http, None);
    assert_eq!(settings.https, None);
    assert_eq!(settings.all, None);
}

#[test]
fn windows_invalid_proxy_does_not_remove_valid_sibling() {
    let settings = current_proxy_settings_for_test(
        "http=ftp://bad.example.com;https=secure.example.com:8443",
        Some("localhost"),
    );
    let expected = &fixtures::SETTINGS_EXPECTATIONS[2];

    assert_eq!(settings.http.as_deref(), expected.http);
    assert_eq!(settings.https.as_deref(), expected.https);
    assert_eq!(settings.all.as_deref(), expected.all);
    assert_eq!(settings.bypass, vec!["localhost"]);
}

#[test]
fn windows_bypass_keeps_quotes_while_canonicalizing_case() {
    let settings = current_proxy_settings_for_test(
        "http=proxy.example.com:8080",
        Some("\"Quoted.COM\";example.com"),
    );

    assert!(settings.bypass.contains(&"\"quoted.com\"".to_string()));
    assert!(settings.bypass.contains(&"example.com".to_string()));
}

#[test]
fn windows_proxy_source_uses_construction_boundary_refresh() {
    let source = WindowsProxySource::new();
    assert_eq!(source.refresh_mode(), RefreshMode::ConstructionBoundary);
}
