use std::collections::BTreeSet;
use std::env;
use std::net::IpAddr;
use ipnet::IpNet;
use reqwest::ClientBuilder;
use reqwest::Url;

use crate::platform::PlatformFeatures;

/// Temporary scaffold to unblock Task 2 extraction work.
///
/// Task 3 will implement real env merging semantics (env vars as fallback/override).
pub(crate) fn merge_env_fallback(features: PlatformFeatures) -> PlatformFeatures {
    features
}

// Test-only module wiring so we can compile and run unit tests for platform parsing
// helpers on any host OS without changing `src/platform.rs` cfg dispatch.
#[cfg(test)]
mod platform {
    pub(crate) mod android {
        include!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/src/platform/android.rs"
        ));
    }

    pub(crate) mod ios {
        include!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/platform/ios.rs"));
    }

    pub(crate) mod macos {
        include!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/platform/macos.rs"));
    }

    pub(crate) mod windows {
        include!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/src/platform/windows.rs"
        ));
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct ProxySnapshot {
    http_proxy: Option<String>,
    https_proxy: Option<String>,
    all_proxy: Option<String>,
    no_proxy: Vec<String>,
}

impl ProxySnapshot {
    pub(crate) fn signature(&self) -> String {
        format!(
            "http={}|https={}|all={}|no={}",
            self.http_proxy.as_deref().unwrap_or(""),
            self.https_proxy.as_deref().unwrap_or(""),
            self.all_proxy.as_deref().unwrap_or(""),
            self.no_proxy.join(","),
        )
    }

    fn has_any_proxy(&self) -> bool {
        self.http_proxy.is_some() || self.https_proxy.is_some() || self.all_proxy.is_some()
    }

    fn dedup_no_proxy(&mut self) {
        let mut set = BTreeSet::<String>::new();
        for item in &self.no_proxy {
            let trimmed = item.trim();
            if !trimmed.is_empty() {
                set.insert(trimmed.to_ascii_lowercase());
            }
        }
        self.no_proxy = set.into_iter().collect();
    }
}

pub(crate) fn current_proxy_snapshot() -> ProxySnapshot {
    load_current_proxy_snapshot()
}

fn load_current_proxy_snapshot() -> ProxySnapshot {
    let platform = crate::platform::current_platform_features();
    let mut system = ProxySnapshot {
        http_proxy: platform.proxy.http,
        https_proxy: platform.proxy.https,
        all_proxy: platform.proxy.all,
        no_proxy: platform.proxy.bypass,
    };
    system.dedup_no_proxy();
    let env_based = env_proxy_snapshot();

    let mut merged = ProxySnapshot {
        http_proxy: system.http_proxy.or(env_based.http_proxy),
        https_proxy: system.https_proxy.or(env_based.https_proxy),
        all_proxy: system.all_proxy.or(env_based.all_proxy),
        no_proxy: [system.no_proxy, env_based.no_proxy].concat(),
    };
    merged.dedup_no_proxy();
    merged
}

pub(crate) fn apply_proxy_strategy(
    builder: ClientBuilder,
    snapshot: &ProxySnapshot,
) -> Result<ClientBuilder, String> {
    let builder = builder.no_proxy();

    if !snapshot.has_any_proxy() {
        return Ok(builder);
    }

    validate_proxy_snapshot(snapshot)?;

    let snapshot = snapshot.clone();
    let proxy = reqwest::Proxy::custom(move |url| {
        select_proxy_for_url(&snapshot, url).map(ToString::to_string)
    });
    Ok(builder.proxy(proxy))
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

fn env_proxy_snapshot() -> ProxySnapshot {
    let mut snapshot = ProxySnapshot {
        http_proxy: env_lookup("HTTP_PROXY", "http_proxy")
            .and_then(|value| normalize_proxy_url(&value, "http")),
        https_proxy: env_lookup("HTTPS_PROXY", "https_proxy")
            .and_then(|value| normalize_proxy_url(&value, "http")),
        all_proxy: env_lookup("ALL_PROXY", "all_proxy")
            .or_else(|| env_lookup("SOCKS_PROXY", "socks_proxy"))
            .and_then(|value| normalize_proxy_url(&value, "http")),
        no_proxy: env_lookup("NO_PROXY", "no_proxy")
            .map(|value| parse_no_proxy_list(&value))
            .unwrap_or_default(),
    };
    snapshot.dedup_no_proxy();
    snapshot
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
    use crate::platform::{PlatformFeatures, ProxySettings};

    #[test]
    fn merge_env_fallback_is_noop_scaffold_for_task_2() {
        let features = PlatformFeatures {
            proxy: ProxySettings {
                http: Some("http://127.0.0.1:8080".to_string()),
                https: Some("http://127.0.0.1:8443".to_string()),
                all: Some("socks5://127.0.0.1:1080".to_string()),
                bypass: vec!["example.com".to_string()],
            },
        };

        assert_eq!(merge_env_fallback(features.clone()), features);
    }

    #[test]
    fn bypass_matches_domains_and_subdomains() {
        let patterns = vec!["example.com".to_string()];
        assert!(should_bypass("example.com", None, &patterns));
        assert!(should_bypass("api.example.com", None, &patterns));
        assert!(!should_bypass("example.org", None, &patterns));
    }

    #[test]
    fn bypass_matches_ips_and_cidr() {
        let patterns = vec!["192.168.10.15".to_string(), "10.0.0.0/8".to_string()];
        assert!(should_bypass("192.168.10.15", None, &patterns));
        assert!(should_bypass("10.1.2.3", None, &patterns));
        assert!(!should_bypass("172.16.0.1", None, &patterns));
    }

    #[test]
    fn bypass_respects_ports_when_present() {
        let patterns = vec!["example.com:8443".to_string()];
        assert!(should_bypass("example.com", Some(8443), &patterns));
        assert!(!should_bypass("example.com", Some(443), &patterns));
    }

    #[test]
    fn bypass_supports_local_hosts_marker() {
        let patterns = vec!["<local>".to_string()];
        assert!(should_bypass("intranet", None, &patterns));
        assert!(!should_bypass("api.example.com", None, &patterns));
    }

    #[test]
    fn normalize_accepts_common_proxy_schemes() {
        assert_eq!(
            normalize_proxy_url("127.0.0.1:7890", "http"),
            Some("http://127.0.0.1:7890/".to_string())
        );
        assert_eq!(
            normalize_proxy_url("socks5://127.0.0.1:1080", "http"),
            Some("socks5://127.0.0.1:1080".to_string())
        );
        assert_eq!(normalize_proxy_url("ftp://127.0.0.1:21", "http"), None);
    }

    #[test]
    fn select_proxy_prefers_specific_scheme_and_bypass() {
        let snapshot = ProxySnapshot {
            http_proxy: Some("http://127.0.0.1:8080".to_string()),
            https_proxy: Some("http://127.0.0.1:8443".to_string()),
            all_proxy: Some("socks5://127.0.0.1:1080".to_string()),
            no_proxy: vec!["direct.example.com".to_string()],
        };

        let http_url = Url::parse("http://api.example.com").unwrap();
        let https_url = Url::parse("https://secure.example.com").unwrap();
        let bypass_url = Url::parse("https://direct.example.com").unwrap();

        assert_eq!(
            select_proxy_for_url(&snapshot, &http_url),
            Some("http://127.0.0.1:8080")
        );
        assert_eq!(
            select_proxy_for_url(&snapshot, &https_url),
            Some("http://127.0.0.1:8443")
        );
        assert_eq!(select_proxy_for_url(&snapshot, &bypass_url), None);
    }
}
