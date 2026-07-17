use nexa_http_native_core::platform::{
    ProxyConfigSource, ProxySettings, RefreshMode, canonicalize_bypass_rules, normalize_proxy_url,
    split_bypass_rules,
};
use std::collections::BTreeMap;

#[cfg(target_os = "android")]
use nexa_http_native_core::platform::clean_proxy_value;
use std::time::Duration;

#[cfg(target_os = "android")]
use std::process::Command;

pub const ANDROID_PROXY_REFRESH_INTERVAL: Duration = Duration::from_secs(15);

#[derive(Clone, Debug, Default)]
pub struct AndroidProxySource;

impl AndroidProxySource {
    pub fn new() -> Self {
        Self
    }
}

impl ProxyConfigSource for AndroidProxySource {
    fn load_current(&self) -> ProxySettings {
        current_proxy_settings()
    }

    fn refresh_mode(&self) -> RefreshMode {
        RefreshMode::Polling {
            interval: ANDROID_PROXY_REFRESH_INTERVAL,
        }
    }
}

pub fn current_proxy_settings_for_test(props: &BTreeMap<String, String>) -> ProxySettings {
    proxy_settings_from_getprop_values(props)
}

fn current_proxy_settings() -> ProxySettings {
    #[cfg(target_os = "android")]
    {
        load_current_proxy_settings()
    }

    #[cfg(not(target_os = "android"))]
    {
        ProxySettings::default()
    }
}

fn proxy_settings_from_getprop_values(props: &BTreeMap<String, String>) -> ProxySettings {
    let http = props
        .get("http.proxyHost")
        .and_then(|host| with_port(host.to_string(), props.get("http.proxyPort").cloned(), 80))
        .and_then(|value| normalize_proxy_url(&value, "http"));
    let https = props
        .get("https.proxyHost")
        .and_then(|host| with_port(host.to_string(), props.get("https.proxyPort").cloned(), 443))
        .and_then(|value| normalize_proxy_url(&value, "http"));
    let socks = props
        .get("socksProxyHost")
        .and_then(|host| with_port(host.to_string(), props.get("socksProxyPort").cloned(), 1080))
        .and_then(|value| normalize_proxy_url(&value, "socks5"));

    let mut bypass = Vec::<String>::new();
    if let Some(value) = props.get("http.nonProxyHosts") {
        bypass.extend(split_bypass_rules(value));
    }
    if let Some(value) = props.get("https.nonProxyHosts") {
        bypass.extend(split_bypass_rules(value));
    }

    let mut settings = ProxySettings {
        http,
        https,
        all: socks,
        bypass,
    };
    settings.bypass = canonicalize_bypass_rules(settings.bypass);
    settings
}

fn with_port(host: String, port: Option<String>, default_port: u16) -> Option<String> {
    let host = host.trim();
    if host.is_empty() {
        return None;
    }

    if host.contains("://") {
        return Some(host.to_string());
    }

    if host.starts_with('[') {
        if host.contains("]:") {
            return Some(host.to_string());
        }
    } else if host.matches(':').count() == 1 {
        let mut splits = host.split(':');
        if splits
            .next_back()
            .and_then(|value| value.parse::<u16>().ok())
            .is_some()
        {
            return Some(host.to_string());
        }
    }

    let port = port
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(default_port);
    Some(format!("{host}:{port}"))
}

#[cfg(target_os = "android")]
fn load_current_proxy_settings() -> ProxySettings {
    let mut props = BTreeMap::<String, String>::new();
    for key in [
        "http.proxyHost",
        "http.proxyPort",
        "https.proxyHost",
        "https.proxyPort",
        "socksProxyHost",
        "socksProxyPort",
        "http.nonProxyHosts",
        "https.nonProxyHosts",
    ] {
        if let Some(value) = getprop(key) {
            props.insert(key.to_string(), value);
        }
    }
    proxy_settings_from_getprop_values(&props)
}

#[cfg(target_os = "android")]
fn getprop(key: &str) -> Option<String> {
    let output = Command::new("getprop").arg(key).output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout)
        .ok()
        .and_then(|value| clean_proxy_value(&value))
}
