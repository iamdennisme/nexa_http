use nexa_http_native_windows_ffi::current_proxy_settings_for_test;

#[test]
fn windows_parses_split_proxy_server_entries() {
    let settings = current_proxy_settings_for_test(
        "http=127.0.0.1:8080;https=127.0.0.1:8443;socks=127.0.0.1:1080",
        Some("localhost;127.0.0.1;*.example.com"),
    );

    assert_eq!(settings.http.as_deref(), Some("http://127.0.0.1:8080/"));
    assert_eq!(settings.https.as_deref(), Some("http://127.0.0.1:8443/"));
    assert_eq!(settings.all.as_deref(), None);
    assert!(settings.bypass.contains(&"localhost".to_string()));
}
