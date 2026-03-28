use nexa_http_native_ios_ffi::current_proxy_settings_for_test;

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
