use nexa_http_native_apple_proxy::{
    AppleProxyEntry, AppleProxySettings, parse_apple_proxy_settings,
};

#[test]
fn enabled_http_proxy_uses_http_default_scheme() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        http: AppleProxyEntry {
            enabled: true,
            host: Some("proxy.example.com".to_string()),
            port: Some(3128),
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(
        settings.http.as_deref(),
        Some("http://proxy.example.com:3128/")
    );
}

#[test]
fn enabled_https_proxy_uses_http_default_scheme() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        https: AppleProxyEntry {
            enabled: true,
            host: Some("secure-proxy.example.com".to_string()),
            port: Some(8443),
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(
        settings.https.as_deref(),
        Some("http://secure-proxy.example.com:8443/")
    );
}

#[test]
fn enabled_socks_proxy_uses_socks5_default_scheme() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        socks: AppleProxyEntry {
            enabled: true,
            host: Some("127.0.0.1".to_string()),
            port: Some(1080),
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(settings.all.as_deref(), Some("socks5://127.0.0.1:1080"));
}

#[test]
fn quoted_proxy_host_is_cleaned_before_parsing() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        http: AppleProxyEntry {
            enabled: true,
            host: Some(r#" "proxy.example.com" "#.to_string()),
            port: Some(3128),
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(
        settings.http.as_deref(),
        Some("http://proxy.example.com:3128/")
    );
}

#[test]
fn unsupported_proxy_scheme_is_ignored() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        http: AppleProxyEntry {
            enabled: true,
            host: Some("ftp://proxy.example.com".to_string()),
            port: None,
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(settings.http, None);
}

#[test]
fn bypass_rules_are_canonicalized_and_include_local_hosts() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        exceptions: vec![
            " Example.COM ".to_string(),
            "example.com".to_string(),
            r#" "*.Example.COM" "#.to_string(),
            "  ".to_string(),
            "LOCALHOST".to_string(),
        ],
        exclude_simple_hostnames: true,
        ..AppleProxySettings::default()
    });

    assert_eq!(
        settings.bypass,
        vec![
            "*.example.com".to_string(),
            "<local>".to_string(),
            "example.com".to_string(),
            "localhost".to_string(),
        ]
    );
}

#[test]
fn non_positive_proxy_port_is_omitted() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        http: AppleProxyEntry {
            enabled: true,
            host: Some("proxy.example.com".to_string()),
            port: Some(0),
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(settings.http.as_deref(), Some("http://proxy.example.com/"));
}

#[test]
fn disabled_and_blank_proxy_entries_are_ignored() {
    let settings = parse_apple_proxy_settings(AppleProxySettings {
        http: AppleProxyEntry {
            enabled: false,
            host: Some("proxy.example.com".to_string()),
            port: Some(3128),
        },
        https: AppleProxyEntry {
            enabled: true,
            host: Some(r#" " "#.to_string()),
            port: Some(8443),
        },
        socks: AppleProxyEntry {
            enabled: true,
            host: None,
            port: Some(1080),
        },
        ..AppleProxySettings::default()
    });

    assert_eq!(settings.http, None);
    assert_eq!(settings.https, None);
    assert_eq!(settings.all, None);
}
