use nexa_http_native_core::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpRequestArgs,
};
use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use once_cell::sync::Lazy;
use reqwest::Url;
use std::collections::{BTreeMap, BTreeSet};
use std::ffi::c_char;

#[cfg(target_os = "android")]
use std::process::Command;
#[cfg(target_os = "android")]
use std::sync::Mutex;
#[cfg(target_os = "android")]
use std::time::{Duration, Instant};

struct AndroidPlatformCapabilities;

impl PlatformCapabilities for AndroidPlatformCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        current_proxy_settings()
    }
}

static RUNTIME: Lazy<NexaHttpRuntime<AndroidPlatformCapabilities>> =
    Lazy::new(|| NexaHttpRuntime::new(AndroidPlatformCapabilities));

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_create(config_json: *const c_char) -> u64 {
    RUNTIME.create_client(config_json)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_execute_async(
    client_id: u64,
    request_id: u64,
    request_args: *const NexaHttpRequestArgs,
    callback: NexaHttpExecuteCallback,
) -> u8 {
    RUNTIME.execute_async(client_id, request_id, request_args, callback)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_execute_binary(
    client_id: u64,
    request_args: *const NexaHttpRequestArgs,
) -> *mut NexaHttpBinaryResult {
    RUNTIME.execute_binary(client_id, request_args)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_binary_result_free(value: *mut NexaHttpBinaryResult) {
    NexaHttpRuntime::<AndroidPlatformCapabilities>::binary_result_free(value);
}

pub fn current_proxy_settings_for_test(props: &BTreeMap<String, String>) -> ProxySettings {
    proxy_settings_from_getprop_values(props)
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

#[cfg(target_os = "android")]
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
