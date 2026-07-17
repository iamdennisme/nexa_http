use std::collections::BTreeMap;

use nexa_http_native_android_ffi::{AndroidProxySource, current_proxy_settings_for_test};
use nexa_http_native_core::platform::{ProxyConfigSource, RefreshMode};

#[path = "../../../../../native/nexa_http_native_core/tests/fixtures/proxy_normalization_cases.rs"]
mod fixtures;

#[test]
fn android_builds_proxy_settings_from_getprop_values() {
    let props = BTreeMap::from([
        (
            "http.proxyHost".to_string(),
            "proxy.example.com".to_string(),
        ),
        ("http.proxyPort".to_string(), "3128".to_string()),
        (
            "https.proxyHost".to_string(),
            "secure.example.com".to_string(),
        ),
        ("https.proxyPort".to_string(), "8443".to_string()),
        ("socksProxyHost".to_string(), "10.0.0.3".to_string()),
        ("socksProxyPort".to_string(), "1081".to_string()),
        (
            "http.nonProxyHosts".to_string(),
            "example.com|localhost".to_string(),
        ),
    ]);

    let settings = current_proxy_settings_for_test(&props);

    assert_eq!(settings.http.as_deref(), fixtures::URL_CASES[0].expected);
    assert_eq!(
        settings.https.as_deref(),
        fixtures::SETTINGS_EXPECTATIONS[2].https
    );
    assert_eq!(settings.all.as_deref(), Some("socks5://10.0.0.3:1081"));
    let expected_bypass = fixtures::VALID_BYPASS
        .iter()
        .map(|item| (*item).to_string())
        .collect::<Vec<_>>();
    assert_eq!(settings.bypass, expected_bypass);
}

#[test]
fn android_empty_properties_are_direct() {
    let settings = current_proxy_settings_for_test(&BTreeMap::new());
    let expected = &fixtures::SETTINGS_EXPECTATIONS[1];

    assert_eq!(settings.http.as_deref(), expected.http);
    assert_eq!(settings.https.as_deref(), expected.https);
    assert_eq!(settings.all.as_deref(), expected.all);
    assert!(settings.bypass.is_empty());
}

#[test]
fn android_invalid_proxy_does_not_remove_valid_sibling() {
    let props = BTreeMap::from([
        (
            "http.proxyHost".to_string(),
            "ftp://bad.example.com".to_string(),
        ),
        ("http.proxyPort".to_string(), "3128".to_string()),
        (
            "https.proxyHost".to_string(),
            "secure.example.com".to_string(),
        ),
        ("https.proxyPort".to_string(), "8443".to_string()),
        ("http.nonProxyHosts".to_string(), "localhost".to_string()),
    ]);
    let settings = current_proxy_settings_for_test(&props);
    let expected = &fixtures::SETTINGS_EXPECTATIONS[2];

    assert_eq!(settings.http.as_deref(), expected.http);
    assert_eq!(settings.https.as_deref(), expected.https);
    assert_eq!(settings.all.as_deref(), expected.all);
    assert_eq!(settings.bypass, vec!["localhost"]);
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
