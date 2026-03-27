use crate::platform::{PlatformFeatures, ProxySettings};
use reqwest::Url;
use std::collections::{BTreeMap, BTreeSet};
#[cfg(target_os = "android")]
use std::time::{Duration, Instant};

#[cfg(target_os = "android")]
use once_cell::sync::Lazy;
#[cfg(target_os = "android")]
use std::process::Command;
#[cfg(target_os = "android")]
use std::sync::Mutex;

pub(crate) fn current() -> PlatformFeatures {
    PlatformFeatures {
        proxy: current_proxy_settings(),
    }
}

fn current_proxy_settings() -> ProxySettings {
    #[cfg(target_os = "android")]
    {
        let mut cache = ANDROID_PROXY_SETTINGS_CACHE.lock().unwrap();
        cache.get_or_refresh(Instant::now(), load_current_proxy_settings)
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
        bypass.extend(parse_bypass_list(value));
    }
    if let Some(value) = props.get("https.nonProxyHosts") {
        bypass.extend(parse_bypass_list(value));
    }

    let mut settings = ProxySettings {
        http,
        https,
        all: socks,
        bypass,
    };
    dedup_bypass(&mut settings);
    settings
}

fn dedup_bypass(settings: &mut ProxySettings) {
    let mut set = BTreeSet::<String>::new();
    for item in &settings.bypass {
        let trimmed = item.trim();
        if !trimmed.is_empty() {
            set.insert(trimmed.to_ascii_lowercase());
        }
    }
    settings.bypass = set.into_iter().collect();
}

fn parse_bypass_list(value: &str) -> Vec<String> {
    value
        .split([',', ';', '|'])
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(|item| item.to_string())
        .collect()
}

fn clean_value(value: String) -> Option<String> {
    let cleaned = value
        .trim()
        .trim_matches('"')
        .trim_matches('\'')
        .trim()
        .to_string();
    if cleaned.is_empty() { None } else { Some(cleaned) }
}

fn normalize_proxy_url(value: &str, default_scheme: &str) -> Option<String> {
    let candidate = if value.contains("://") {
        value.to_string()
    } else {
        format!("{default_scheme}://{value}")
    };

    let parsed = Url::parse(&candidate).ok()?;
    match parsed.scheme() {
        "http" | "https" | "socks4" | "socks4a" | "socks5" | "socks5h" => Some(parsed.to_string()),
        _ => None,
    }
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
#[derive(Debug, Clone)]
struct CachedProxySettings {
    settings: ProxySettings,
    refreshed_at: Instant,
}

#[cfg(target_os = "android")]
#[derive(Debug)]
struct ProxySettingsCache {
    ttl: Duration,
    cached: Option<CachedProxySettings>,
}

#[cfg(target_os = "android")]
impl ProxySettingsCache {
    fn new(ttl: Duration) -> Self {
        Self { ttl, cached: None }
    }

    fn get_or_refresh<F>(&mut self, now: Instant, refresh: F) -> ProxySettings
    where
        F: FnOnce() -> ProxySettings,
    {
        if let Some(cached) = &self.cached {
            if now
                .checked_duration_since(cached.refreshed_at)
                .map(|elapsed| elapsed < self.ttl)
                .unwrap_or(false)
            {
                return cached.settings.clone();
            }
        }

        let settings = refresh();
        self.cached = Some(CachedProxySettings {
            settings: settings.clone(),
            refreshed_at: now,
        });
        settings
    }
}

#[cfg(target_os = "android")]
static ANDROID_PROXY_SETTINGS_CACHE: Lazy<Mutex<ProxySettingsCache>> =
    Lazy::new(|| Mutex::new(ProxySettingsCache::new(Duration::from_secs(5))));

#[cfg(target_os = "android")]
fn load_current_proxy_settings() -> ProxySettings {
    // Read getprop once per key; build a plain map so the mapping logic is testable.
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
    String::from_utf8(output.stdout).ok().and_then(clean_value)
}

#[cfg(test)]
mod tests {
    use super::*;

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

        let settings = proxy_settings_from_getprop_values(&props);

        assert_eq!(settings.http.as_deref(), Some("http://10.0.0.1:3128/"));
        assert_eq!(settings.https.as_deref(), Some("http://10.0.0.2:8443/"));
        assert_eq!(settings.all.as_deref(), Some("socks5://10.0.0.3:1081"));
        assert!(settings.bypass.contains(&"localhost".to_string()));
        assert!(settings.bypass.contains(&"127.0.0.1".to_string()));
        assert!(settings.bypass.contains(&"*.example.com".to_string()));
    }

    #[test]
    fn android_with_port_appends_default_port_when_missing() {
        assert_eq!(
            with_port("proxy.example.com".to_string(), None, 80).as_deref(),
            Some("proxy.example.com:80")
        );
    }

    #[test]
    fn android_with_port_preserves_explicit_port() {
        assert_eq!(
            with_port("proxy.example.com:3128".to_string(), None, 80).as_deref(),
            Some("proxy.example.com:3128")
        );
    }

    #[test]
    fn android_with_port_preserves_bracketed_ipv6() {
        assert_eq!(
            with_port("[::1]".to_string(), Some("8888".to_string()), 80).as_deref(),
            Some("[::1]:8888")
        );
        assert_eq!(
            with_port("[::1]:9999".to_string(), Some("8888".to_string()), 80).as_deref(),
            Some("[::1]:9999")
        );
    }
}
