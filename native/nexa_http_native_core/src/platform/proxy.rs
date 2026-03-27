use ipnet::IpNet;
use reqwest::ClientBuilder;
use reqwest::Url;
use std::collections::BTreeSet;
use std::env;
use std::net::IpAddr;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct PlatformFeatures {
    pub proxy: ProxySettings,
}

impl PlatformFeatures {
    pub fn from_proxy_settings(proxy: ProxySettings) -> Self {
        Self { proxy }
    }

    pub fn signature(&self) -> String {
        self.proxy.signature()
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ProxySettings {
    pub http: Option<String>,
    pub https: Option<String>,
    pub all: Option<String>,
    pub bypass: Vec<String>,
}

impl ProxySettings {
    pub fn is_empty(&self) -> bool {
        self.http.is_none() && self.https.is_none() && self.all.is_none()
    }

    pub fn signature(&self) -> String {
        format!(
            "http={}|https={}|all={}|no={}",
            self.http.as_deref().unwrap_or(""),
            self.https.as_deref().unwrap_or(""),
            self.all.as_deref().unwrap_or(""),
            self.bypass.join(","),
        )
    }

    pub fn signature_for_test(&self) -> String {
        self.signature()
    }
}

/// Merge env var-based proxy config into platform-discovered features.
///
/// Semantics: platform/system proxy settings take priority; env vars are fallback.
/// Bypass lists are appended then deduped.
pub fn merge_env_fallback(features: PlatformFeatures) -> PlatformFeatures {
    let env_proxy = env_proxy_settings();
    merge_env_fallback_with_settings(features, env_proxy)
}

fn merge_env_fallback_with_settings(
    mut features: PlatformFeatures,
    mut env_proxy: ProxySettings,
) -> PlatformFeatures {
    features.proxy.http = features.proxy.http.or(env_proxy.http.take());
    features.proxy.https = features.proxy.https.or(env_proxy.https.take());
    features.proxy.all = features.proxy.all.or(env_proxy.all.take());

    features.proxy.bypass.append(&mut env_proxy.bypass);
    canonicalize_bypass_rules(&mut features.proxy.bypass);
    features
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
struct ProxySnapshot {
    http_proxy: Option<String>,
    https_proxy: Option<String>,
    all_proxy: Option<String>,
    no_proxy: Vec<String>,
}

impl ProxySnapshot {
    fn has_any_proxy(&self) -> bool {
        self.http_proxy.is_some() || self.https_proxy.is_some() || self.all_proxy.is_some()
    }

    fn dedup_no_proxy(&mut self) {
        canonicalize_bypass_rules(&mut self.no_proxy);
    }
}

pub fn apply_proxy_strategy(
    builder: ClientBuilder,
    platform_features: &PlatformFeatures,
) -> Result<ClientBuilder, String> {
    let builder = builder.no_proxy();

    let snapshot = snapshot_from_proxy_settings(&platform_features.proxy);
    if !snapshot.has_any_proxy() {
        return Ok(builder);
    }

    validate_proxy_snapshot(&snapshot)?;

    let snapshot = snapshot.clone();
    let proxy = reqwest::Proxy::custom(move |url| {
        select_proxy_for_url(&snapshot, url).map(ToString::to_string)
    });
    Ok(builder.proxy(proxy))
}

fn snapshot_from_proxy_settings(settings: &ProxySettings) -> ProxySnapshot {
    let mut snapshot = ProxySnapshot {
        http_proxy: settings.http.clone(),
        https_proxy: settings.https.clone(),
        all_proxy: settings.all.clone(),
        no_proxy: settings.bypass.clone(),
    };
    snapshot.dedup_no_proxy();
    snapshot
}

fn validate_proxy_snapshot(snapshot: &ProxySnapshot) -> Result<(), String> {
    for (label, value) in [
        ("http_proxy", snapshot.http_proxy.as_deref()),
        ("https_proxy", snapshot.https_proxy.as_deref()),
        ("all_proxy", snapshot.all_proxy.as_deref()),
    ] {
        if let Some(proxy) = value {
            Url::parse(proxy)
                .map_err(|error| format!("Invalid {label} value '{proxy}': {error}"))?;
        }
    }
    Ok(())
}

fn select_proxy_for_url<'a>(snapshot: &'a ProxySnapshot, url: &Url) -> Option<&'a str> {
    let host = url.host_str()?;
    if should_bypass(host, url.port_or_known_default(), &snapshot.no_proxy) {
        return None;
    }

    match url.scheme() {
        "http" => snapshot
            .http_proxy
            .as_deref()
            .or(snapshot.all_proxy.as_deref()),
        "https" => snapshot
            .https_proxy
            .as_deref()
            .or(snapshot.all_proxy.as_deref())
            .or(snapshot.http_proxy.as_deref()),
        _ => snapshot.all_proxy.as_deref(),
    }
}

fn should_bypass(host: &str, port: Option<u16>, patterns: &[String]) -> bool {
    if patterns.is_empty() {
        return false;
    }

    let host_lower = host.to_ascii_lowercase();
    let parsed_ip = host.parse::<IpAddr>().ok();

    for pattern in patterns {
        let pattern = pattern.trim();
        if pattern.is_empty() {
            continue;
        }
        if pattern == "*" {
            return true;
        }
        if pattern.eq_ignore_ascii_case("<local>") {
            if parsed_ip.is_none() && !host_lower.contains('.') {
                return true;
            }
            continue;
        }

        let (raw_host_pattern, raw_port_pattern) = split_host_port_pattern(pattern);
        let host_pattern = normalize_host_pattern(raw_host_pattern);

        if let Some(expected_port) = raw_port_pattern {
            if let Some(actual_port) = port {
                if expected_port != actual_port {
                    continue;
                }
            } else {
                continue;
            }
        }

        if let Some(ip) = parsed_ip {
            if ip_match(ip, &host_pattern) {
                return true;
            }
            continue;
        }

        if host_pattern == host_lower {
            return true;
        }
        if host_lower.ends_with(&format!(".{host_pattern}")) {
            return true;
        }
    }

    false
}

fn ip_match(ip: IpAddr, pattern: &str) -> bool {
    if let Ok(net) = pattern.parse::<IpNet>() {
        return net.contains(&ip);
    }

    if let Ok(exact_ip) = pattern.parse::<IpAddr>() {
        return exact_ip == ip;
    }

    false
}

fn split_host_port_pattern(pattern: &str) -> (String, Option<u16>) {
    if let Some(rest) = pattern.strip_prefix('[') {
        if let Some((host, port_text)) = rest.split_once("]:") {
            let port = port_text.parse::<u16>().ok();
            return (host.to_string(), port);
        }
        if let Some(host) = rest.strip_suffix(']') {
            return (host.to_string(), None);
        }
    }

    if let Some((host, port_text)) = pattern.rsplit_once(':') {
        if host.contains(':') {
            return (pattern.to_string(), None);
        }
        if let Ok(port) = port_text.parse::<u16>() {
            return (host.to_string(), Some(port));
        }
    }

    (pattern.to_string(), None)
}

fn normalize_host_pattern(pattern: String) -> String {
    let trimmed = pattern.trim();
    let trimmed = trimmed
        .strip_prefix("http://")
        .or_else(|| trimmed.strip_prefix("https://"))
        .or_else(|| trimmed.strip_prefix("socks5://"))
        .or_else(|| trimmed.strip_prefix("socks5h://"))
        .or_else(|| trimmed.strip_prefix("socks4://"))
        .or_else(|| trimmed.strip_prefix("socks4a://"))
        .unwrap_or(trimmed);

    trimmed
        .trim_start_matches('.')
        .trim_start_matches("*.")
        .to_ascii_lowercase()
}

fn env_proxy_settings() -> ProxySettings {
    let mut settings = ProxySettings {
        http: env_lookup("HTTP_PROXY", "http_proxy")
            .and_then(|value| normalize_proxy_url(&value, "http")),
        https: env_lookup("HTTPS_PROXY", "https_proxy")
            .and_then(|value| normalize_proxy_url(&value, "http")),
        all: env_lookup("ALL_PROXY", "all_proxy")
            .or_else(|| env_lookup("SOCKS_PROXY", "socks_proxy"))
            .and_then(|value| normalize_proxy_url(&value, "http")),
        bypass: env_lookup("NO_PROXY", "no_proxy")
            .map(|value| parse_no_proxy_list(&value))
            .unwrap_or_default(),
    };
    canonicalize_bypass_rules(&mut settings.bypass);
    settings
}

fn canonicalize_bypass_rules(bypass: &mut Vec<String>) {
    let mut set = BTreeSet::<String>::new();
    for item in bypass.iter() {
        let trimmed = item.trim();
        if !trimmed.is_empty() {
            set.insert(trimmed.to_ascii_lowercase());
        }
    }
    *bypass = set.into_iter().collect();
}

fn env_lookup(primary: &str, secondary: &str) -> Option<String> {
    env::var(primary)
        .ok()
        .or_else(|| env::var(secondary).ok())
        .and_then(clean_value)
}

fn clean_value(value: String) -> Option<String> {
    let cleaned = value
        .trim()
        .trim_matches('"')
        .trim_matches('\'')
        .trim()
        .to_string();

    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned)
    }
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

fn parse_no_proxy_list(value: &str) -> Vec<String> {
    value
        .split([',', ';', '|'])
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(|item| item.to_string())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merge_env_fallback_keeps_system_proxy_priority() {
        let features = PlatformFeatures {
            proxy: ProxySettings {
                http: Some("http://system-proxy:8000".to_string()),
                https: None,
                all: None,
                bypass: vec!["system.example.com".to_string()],
            },
        };

        let env_proxy = ProxySettings {
            http: Some("http://env-proxy:8080/".to_string()),
            https: Some("http://env-secure:8443/".to_string()),
            all: Some("socks5://env-all:1080".to_string()),
            bypass: vec!["env.example.com".to_string()],
        };

        let merged = merge_env_fallback_with_settings(features, env_proxy);

        assert_eq!(
            merged.proxy.http.as_deref(),
            Some("http://system-proxy:8000")
        );
        assert_eq!(
            merged.proxy.https.as_deref(),
            Some("http://env-secure:8443/")
        );
        assert_eq!(merged.proxy.all.as_deref(), Some("socks5://env-all:1080"));
    }
}
