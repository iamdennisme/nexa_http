use std::collections::BTreeMap;

use nexa_http_native_android_ffi::{AndroidProxySource, current_proxy_settings_for_test};
use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};

#[test]
fn android_builds_proxy_settings_from_getprop_values() {
    let props = BTreeMap::from([
        ("http.proxyHost".to_string(), "10.0.0.1".to_string()),
        ("http.proxyPort".to_string(), "3128".to_string()),
        ("https.proxyHost".to_string(), "10.0.0.2".to_string()),
        ("https.proxyPort".to_string(), "8443".to_string()),
        ("socksProxyHost".to_string(), "10.0.0.3".to_string()),
        ("socksProxyPort".to_string(), "1081".to_string()),
        (
            "http.nonProxyHosts".to_string(),
            "localhost|127.0.0.1|*.example.com".to_string(),
        ),
    ]);

    let settings = current_proxy_settings_for_test(&props);

    assert_eq!(settings.http.as_deref(), Some("http://10.0.0.1:3128/"));
    assert_eq!(settings.https.as_deref(), Some("http://10.0.0.2:8443/"));
    assert_eq!(settings.all.as_deref(), Some("socks5://10.0.0.3:1081"));
}

#[test]
fn android_proxy_source_uses_a_bounded_platform_refresh_policy() {
    let source = AndroidProxySource::new();

    match source.refresh_mode() {
        RefreshMode::Polling { interval } => {
            assert!(interval >= std::time::Duration::from_secs(5));
        }
        other => panic!("expected polling refresh mode, got {other:?}"),
    }
}
