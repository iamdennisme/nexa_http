use std::collections::BTreeSet;
use std::env;
use std::net::IpAddr;
#[cfg(any(target_os = "android", target_os = "linux"))]
use std::process::Command;

#[cfg(any(target_os = "ios", target_os = "macos"))]
use core_foundation::array::{CFArray, CFArrayRef};
#[cfg(any(target_os = "ios", target_os = "macos"))]
use core_foundation::base::{CFRelease, TCFType};
#[cfg(any(target_os = "ios", target_os = "macos"))]
use core_foundation::dictionary::{CFDictionaryGetValue, CFDictionaryRef};
#[cfg(any(target_os = "ios", target_os = "macos"))]
use core_foundation::number::{CFNumberGetValue, CFNumberRef, kCFNumberSInt32Type};
#[cfg(any(target_os = "ios", target_os = "macos"))]
use core_foundation::string::{CFString, CFStringRef};
use ipnet::IpNet;
use reqwest::ClientBuilder;
use reqwest::Url;
#[cfg(any(target_os = "ios", target_os = "macos"))]
use std::ffi::c_void;
#[cfg(any(target_os = "ios", target_os = "macos"))]
use std::ptr;
#[cfg(any(target_os = "ios", target_os = "macos"))]
use system_configuration_sys::dynamic_store_copy_specific::SCDynamicStoreCopyProxies;
#[cfg(any(target_os = "ios", target_os = "macos"))]
use system_configuration_sys::schema_definitions::{
    kSCPropNetProxiesExceptionsList, kSCPropNetProxiesExcludeSimpleHostnames,
    kSCPropNetProxiesHTTPEnable, kSCPropNetProxiesHTTPPort, kSCPropNetProxiesHTTPProxy,
    kSCPropNetProxiesHTTPSEnable, kSCPropNetProxiesHTTPSPort, kSCPropNetProxiesHTTPSProxy,
    kSCPropNetProxiesSOCKSEnable, kSCPropNetProxiesSOCKSPort, kSCPropNetProxiesSOCKSProxy,
};
#[cfg(target_os = "windows")]
use winreg::{RegKey, enums};

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
    let system = system_proxy_snapshot();
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

#[cfg(target_os = "android")]
fn system_proxy_snapshot() -> ProxySnapshot {
    android_proxy_snapshot()
}

#[cfg(target_os = "ios")]
fn system_proxy_snapshot() -> ProxySnapshot {
    apple_proxy_snapshot()
}

#[cfg(target_os = "linux")]
fn system_proxy_snapshot() -> ProxySnapshot {
    linux_proxy_snapshot()
}

#[cfg(target_os = "macos")]
fn system_proxy_snapshot() -> ProxySnapshot {
    apple_proxy_snapshot()
}

#[cfg(target_os = "windows")]
fn system_proxy_snapshot() -> ProxySnapshot {
    windows_proxy_snapshot()
}

#[cfg(not(any(
    target_os = "android",
    target_os = "ios",
    target_os = "linux",
    target_os = "macos",
    target_os = "windows",
)))]
fn system_proxy_snapshot() -> ProxySnapshot {
    ProxySnapshot::default()
}

#[cfg(target_os = "android")]
fn android_proxy_snapshot() -> ProxySnapshot {
    let http_proxy = getprop("http.proxyHost")
        .and_then(|host| with_port(host, getprop("http.proxyPort"), 80))
        .and_then(|value| normalize_proxy_url(&value, "http"));
    let https_proxy = getprop("https.proxyHost")
        .and_then(|host| with_port(host, getprop("https.proxyPort"), 443))
        .and_then(|value| normalize_proxy_url(&value, "http"));
    let socks_proxy = getprop("socksProxyHost")
        .and_then(|host| with_port(host, getprop("socksProxyPort"), 1080))
        .and_then(|value| normalize_proxy_url(&value, "socks5"));

    let mut no_proxy = Vec::new();
    if let Some(value) = getprop("http.nonProxyHosts") {
        no_proxy.extend(parse_no_proxy_list(&value));
    }
    if let Some(value) = getprop("https.nonProxyHosts") {
        no_proxy.extend(parse_no_proxy_list(&value));
    }

    let mut snapshot = ProxySnapshot {
        http_proxy,
        https_proxy,
        all_proxy: socks_proxy,
        no_proxy,
    };
    snapshot.dedup_no_proxy();
    snapshot
}

#[cfg(target_os = "android")]
fn getprop(key: &str) -> Option<String> {
    let output = Command::new("getprop").arg(key).output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout).ok().and_then(clean_value)
}

#[cfg(target_os = "android")]
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

#[cfg(target_os = "linux")]
fn linux_proxy_snapshot() -> ProxySnapshot {
    let gnome = gnome_proxy_snapshot();
    if gnome.has_any_proxy() || !gnome.no_proxy.is_empty() {
        return gnome;
    }

    let kde = kde_proxy_snapshot();
    if kde.has_any_proxy() || !kde.no_proxy.is_empty() {
        return kde;
    }

    ProxySnapshot::default()
}

#[cfg(target_os = "linux")]
fn gnome_proxy_snapshot() -> ProxySnapshot {
    let mode = gsettings_get("org.gnome.system.proxy", "mode");
    if mode.as_deref() != Some("manual") {
        return ProxySnapshot::default();
    }

    let mut snapshot = ProxySnapshot {
        http_proxy: gsettings_proxy("http", "http"),
        https_proxy: gsettings_proxy("https", "http"),
        all_proxy: gsettings_proxy("socks", "socks5"),
        no_proxy: gsettings_get_list("org.gnome.system.proxy", "ignore-hosts"),
    };

    if gsettings_get("org.gnome.system.proxy", "use-same-proxy").as_deref() == Some("true") {
        if snapshot.https_proxy.is_none() {
            snapshot.https_proxy = snapshot.http_proxy.clone();
        }
    }

    snapshot.dedup_no_proxy();
    snapshot
}

#[cfg(target_os = "linux")]
fn gsettings_proxy(service: &str, scheme: &str) -> Option<String> {
    let schema = format!("org.gnome.system.proxy.{service}");
    let host = gsettings_get(&schema, "host")?;
    let port = gsettings_get(&schema, "port")
        .and_then(|value| value.parse::<u16>().ok())
        .filter(|value| *value > 0);
    let host_port = match port {
        Some(port) => format!("{host}:{port}"),
        None => host,
    };
    normalize_proxy_url(&host_port, scheme)
}

#[cfg(target_os = "linux")]
fn gsettings_get(schema: &str, key: &str) -> Option<String> {
    let output = Command::new("gsettings")
        .args(["get", schema, key])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout).ok().and_then(clean_value)
}

#[cfg(target_os = "linux")]
fn gsettings_get_list(schema: &str, key: &str) -> Vec<String> {
    let output = match Command::new("gsettings")
        .args(["get", schema, key])
        .output()
    {
        Ok(output) if output.status.success() => output,
        _ => return Vec::new(),
    };
    let raw = match String::from_utf8(output.stdout) {
        Ok(raw) => raw,
        Err(_) => return Vec::new(),
    };
    let trimmed = raw.trim().trim_start_matches('[').trim_end_matches(']');
    parse_no_proxy_list(trimmed)
        .into_iter()
        .filter_map(|item| clean_value(item))
        .collect()
}

#[cfg(target_os = "linux")]
fn kde_proxy_snapshot() -> ProxySnapshot {
    let kreadconfig = match find_kreadconfig() {
        Some(value) => value,
        None => return ProxySnapshot::default(),
    };

    let proxy_type = match kreadconfig_get(&kreadconfig, "Proxy Settings", "ProxyType") {
        Some(value) => value,
        None => return ProxySnapshot::default(),
    };
    if proxy_type != "1" {
        return ProxySnapshot::default();
    }

    let mut snapshot = ProxySnapshot {
        http_proxy: kreadconfig_get(&kreadconfig, "Proxy Settings", "httpProxy")
            .and_then(|value| normalize_proxy_url(&value, "http")),
        https_proxy: kreadconfig_get(&kreadconfig, "Proxy Settings", "httpsProxy")
            .and_then(|value| normalize_proxy_url(&value, "http")),
        all_proxy: kreadconfig_get(&kreadconfig, "Proxy Settings", "socksProxy")
            .and_then(|value| normalize_proxy_url(&value, "socks5")),
        no_proxy: kreadconfig_get(&kreadconfig, "Proxy Settings", "NoProxyFor")
            .map(|value| parse_no_proxy_list(&value))
            .unwrap_or_default(),
    };
    snapshot.dedup_no_proxy();
    snapshot
}

#[cfg(target_os = "linux")]
fn find_kreadconfig() -> Option<String> {
    for candidate in ["kreadconfig6", "kreadconfig5"] {
        if Command::new(candidate).arg("--help").output().is_ok() {
            return Some(candidate.to_string());
        }
    }
    None
}

#[cfg(target_os = "linux")]
fn kreadconfig_get(binary: &str, group: &str, key: &str) -> Option<String> {
    let output = Command::new(binary)
        .args(["--group", group, "--key", key])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout).ok().and_then(clean_value)
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_proxy_snapshot() -> ProxySnapshot {
    struct ProxiesRef(CFDictionaryRef);

    impl Drop for ProxiesRef {
        fn drop(&mut self) {
            unsafe {
                CFRelease(self.0 as *const c_void);
            }
        }
    }

    let proxies = unsafe { SCDynamicStoreCopyProxies(ptr::null()) };
    if proxies.is_null() {
        return ProxySnapshot::default();
    }
    let proxies = ProxiesRef(proxies);

    let mut snapshot = ProxySnapshot {
        http_proxy: apple_proxy_entry(
            proxies.0,
            unsafe { kSCPropNetProxiesHTTPEnable },
            unsafe { kSCPropNetProxiesHTTPProxy },
            unsafe { kSCPropNetProxiesHTTPPort },
            "http",
        ),
        https_proxy: apple_proxy_entry(
            proxies.0,
            unsafe { kSCPropNetProxiesHTTPSEnable },
            unsafe { kSCPropNetProxiesHTTPSProxy },
            unsafe { kSCPropNetProxiesHTTPSPort },
            "http",
        ),
        all_proxy: apple_proxy_entry(
            proxies.0,
            unsafe { kSCPropNetProxiesSOCKSEnable },
            unsafe { kSCPropNetProxiesSOCKSProxy },
            unsafe { kSCPropNetProxiesSOCKSPort },
            "socks5",
        ),
        no_proxy: apple_proxy_exceptions(proxies.0),
    };
    snapshot.dedup_no_proxy();
    snapshot
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_proxy_entry(
    proxies: CFDictionaryRef,
    enabled_key: CFStringRef,
    host_key: CFStringRef,
    port_key: CFStringRef,
    scheme: &str,
) -> Option<String> {
    if !apple_dictionary_bool(proxies, enabled_key) {
        return None;
    }

    let host = apple_dictionary_string(proxies, host_key)?;
    let port = apple_dictionary_i32(proxies, port_key).filter(|value| *value > 0);
    let host_port = match port {
        Some(port) => format!("{host}:{port}"),
        None => host,
    };
    normalize_proxy_url(&host_port, scheme)
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_proxy_exceptions(proxies: CFDictionaryRef) -> Vec<String> {
    let mut result =
        apple_dictionary_string_array(proxies, unsafe { kSCPropNetProxiesExceptionsList });
    if apple_dictionary_bool(proxies, unsafe { kSCPropNetProxiesExcludeSimpleHostnames }) {
        result.push("<local>".to_string());
    }
    result
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_dictionary_value(proxies: CFDictionaryRef, key: CFStringRef) -> *const c_void {
    unsafe { CFDictionaryGetValue(proxies, key as *const c_void) }
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_dictionary_bool(proxies: CFDictionaryRef, key: CFStringRef) -> bool {
    apple_dictionary_i32(proxies, key).unwrap_or(0) == 1
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_dictionary_i32(proxies: CFDictionaryRef, key: CFStringRef) -> Option<i32> {
    let value = apple_dictionary_value(proxies, key);
    if value.is_null() {
        return None;
    }

    let mut number = 0i32;
    let ok = unsafe {
        CFNumberGetValue(
            value as CFNumberRef,
            kCFNumberSInt32Type,
            &mut number as *mut i32 as *mut c_void,
        )
    };
    if ok { Some(number) } else { None }
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_dictionary_string(proxies: CFDictionaryRef, key: CFStringRef) -> Option<String> {
    let value = apple_dictionary_value(proxies, key);
    if value.is_null() {
        return None;
    }
    clean_value(unsafe { CFString::wrap_under_get_rule(value as CFStringRef) }.to_string())
}

#[cfg(any(target_os = "ios", target_os = "macos"))]
fn apple_dictionary_string_array(proxies: CFDictionaryRef, key: CFStringRef) -> Vec<String> {
    let value = apple_dictionary_value(proxies, key);
    if value.is_null() {
        return Vec::new();
    }

    let array = unsafe { CFArray::<CFString>::wrap_under_get_rule(value as CFArrayRef) };
    array
        .iter()
        .filter_map(|item| clean_value(item.to_string()))
        .collect()
}

#[cfg(target_os = "windows")]
fn windows_proxy_snapshot() -> ProxySnapshot {
    const SUB_KEY: &str = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";

    let hkcu = RegKey::predef(enums::HKEY_CURRENT_USER);
    let key = match hkcu.open_subkey_with_flags(SUB_KEY, enums::KEY_READ) {
        Ok(key) => key,
        Err(_) => return ProxySnapshot::default(),
    };

    if key.get_value::<u32, _>("ProxyEnable").ok() != Some(1) {
        return ProxySnapshot::default();
    }

    let server = match key.get_value::<String, _>("ProxyServer") {
        Ok(value) => value,
        Err(_) => return ProxySnapshot::default(),
    };
    let bypass = key
        .get_value::<String, _>("ProxyOverride")
        .ok()
        .map(|value| parse_no_proxy_list(&value))
        .unwrap_or_default();

    let mut snapshot = ProxySnapshot {
        no_proxy: bypass,
        ..ProxySnapshot::default()
    };

    if server.contains('=') {
        for entry in server
            .split(';')
            .map(str::trim)
            .filter(|entry| !entry.is_empty())
        {
            let Some((scheme, address)) = entry.split_once('=') else {
                continue;
            };

            let normalized = match scheme.to_ascii_lowercase().as_str() {
                "http" => normalize_proxy_url(address, "http"),
                "https" => normalize_proxy_url(address, "http"),
                "socks" | "socks4" | "socks4a" | "socks5" | "socks5h" => {
                    normalize_proxy_url(address, scheme)
                }
                _ => None,
            };

            match scheme.to_ascii_lowercase().as_str() {
                "http" => snapshot.http_proxy = normalized,
                "https" => snapshot.https_proxy = normalized,
                "socks" | "socks4" | "socks4a" | "socks5" | "socks5h" => {
                    snapshot.all_proxy = normalized
                }
                _ => {}
            }
        }
    } else {
        let normalized = normalize_proxy_url(&server, "http");
        snapshot.http_proxy = normalized.clone();
        snapshot.https_proxy = normalized;
    }

    snapshot.dedup_no_proxy();
    snapshot
}

#[cfg(test)]
mod tests {
    use super::*;

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
