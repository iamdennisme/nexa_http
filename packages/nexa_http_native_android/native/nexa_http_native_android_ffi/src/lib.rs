use nexa_http_native_core::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpRequestArgs,
};
use nexa_http_native_core::platform::{PlatformRuntimeState, PlatformRuntimeView, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use once_cell::sync::Lazy;
use reqwest::Url;
use std::collections::{BTreeMap, BTreeSet};
use std::ffi::c_char;
use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
    RwLock,
};
use std::thread;
use std::time::Duration;

#[cfg(target_os = "android")]
use std::process::Command;

const PROXY_REFRESH_INTERVAL: Duration = Duration::from_millis(500);

#[derive(Debug)]
pub struct ProxyRuntimeState {
    generation: AtomicU64,
    snapshot: RwLock<ProxySettings>,
}

impl ProxyRuntimeState {
    pub fn new(initial_snapshot: ProxySettings) -> Self {
        Self {
            generation: AtomicU64::new(0),
            snapshot: RwLock::new(initial_snapshot),
        }
    }

    pub fn current_proxy_snapshot(&self) -> ProxySettings {
        self.snapshot
            .read()
            .expect("proxy runtime state poisoned")
            .clone()
    }

    pub fn current_platform_state(&self) -> PlatformRuntimeView {
        let snapshot = self
            .snapshot
            .read()
            .expect("proxy runtime state poisoned")
            .clone();
        PlatformRuntimeView::with_proxy_settings(
            self.generation.load(Ordering::SeqCst),
            snapshot,
        )
    }

    pub fn update_snapshot(&self, next_snapshot: ProxySettings) -> bool {
        let mut snapshot = self
            .snapshot
            .write()
            .expect("proxy runtime state poisoned");
        if *snapshot == next_snapshot {
            return false;
        }

        *snapshot = next_snapshot;
        self.generation.fetch_add(1, Ordering::SeqCst);
        true
    }

    pub fn refresh_with<F>(&self, load_snapshot: F) -> PlatformRuntimeView
    where
        F: FnOnce() -> ProxySettings,
    {
        let next_snapshot = load_snapshot();
        self.update_snapshot(next_snapshot);
        self.current_platform_state()
    }
}

#[derive(Debug)]
struct AndroidPlatformRuntime {
    state: Arc<ProxyRuntimeState>,
}

impl AndroidPlatformRuntime {
    fn new() -> Self {
        let state = Arc::new(ProxyRuntimeState::new(current_proxy_settings()));
        spawn_proxy_refresh_worker(Arc::clone(&state));
        Self { state }
    }
}

impl PlatformRuntimeState for AndroidPlatformRuntime {
    fn proxy_generation(&self) -> u64 {
        self.state.generation.load(Ordering::SeqCst)
    }

    fn current_platform_state(&self) -> PlatformRuntimeView {
        self.state.current_platform_state()
    }
}

fn spawn_proxy_refresh_worker(state: Arc<ProxyRuntimeState>) {
    let _ = thread::Builder::new()
        .name("nexa-http-android-proxy".to_string())
        .spawn(move || {
            loop {
                thread::sleep(PROXY_REFRESH_INTERVAL);
                state.update_snapshot(current_proxy_settings());
            }
        });
}

static RUNTIME: Lazy<NexaHttpRuntime<AndroidPlatformRuntime>> =
    Lazy::new(|| NexaHttpRuntime::new(AndroidPlatformRuntime::new()));

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
pub extern "C" fn nexa_http_runtime_prefers_binary_execution() -> u8 {
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_binary_result_free(value: *mut NexaHttpBinaryResult) {
    NexaHttpRuntime::<AndroidPlatformRuntime>::binary_result_free(value);
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
