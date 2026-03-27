use nexa_http_native_macos_ffi::current_proxy_settings_for_test;

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
