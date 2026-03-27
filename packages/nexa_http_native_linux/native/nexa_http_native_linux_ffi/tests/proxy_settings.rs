use nexa_http_native_linux_ffi::current_proxy_settings_for_test;

#[test]
fn linux_defaults_to_empty_proxy_settings_in_v1() {
    let settings = current_proxy_settings_for_test();
    assert_eq!(settings, nexa_http_native_core::platform::ProxySettings::default());
}
