use nexa_http_native_core::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpRequestArgs,
};
use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use once_cell::sync::Lazy;
use reqwest::Url;
use std::collections::BTreeSet;
use std::ffi::c_char;

#[cfg(target_os = "windows")]
use winreg::{RegKey, enums};

struct WindowsPlatformCapabilities;

impl PlatformCapabilities for WindowsPlatformCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        current_proxy_settings()
    }
}

static RUNTIME: Lazy<NexaHttpRuntime<WindowsPlatformCapabilities>> =
    Lazy::new(|| NexaHttpRuntime::new(WindowsPlatformCapabilities));

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
    NexaHttpRuntime::<WindowsPlatformCapabilities>::binary_result_free(value);
}

pub fn current_proxy_settings_for_test(server: &str, bypass: Option<&str>) -> ProxySettings {
    proxy_settings_from_proxy_server(server, bypass)
}

fn current_proxy_settings() -> ProxySettings {
    #[cfg(target_os = "windows")]
    {
        registry::current_proxy_settings()
    }

    #[cfg(not(target_os = "windows"))]
    {
        ProxySettings::default()
    }
}

fn proxy_settings_from_proxy_server(server: &str, bypass: Option<&str>) -> ProxySettings {
    let server = server.trim();
    if server.is_empty() {
        return ProxySettings::default();
    }

    let mut settings = ProxySettings::default();

    if server.contains('=') {
        for entry in server
            .split(';')
            .map(str::trim)
            .filter(|entry| !entry.is_empty())
        {
            let Some((scheme, address)) = entry.split_once('=') else {
                continue;
            };
            let scheme_lower = scheme.trim().to_ascii_lowercase();
            let address = address.trim();

            match scheme_lower.as_str() {
                "http" => settings.http = normalize_proxy_url(address, "http"),
                "https" => settings.https = normalize_proxy_url(address, "http"),
                "socks" | "socks4" | "socks4a" | "socks5" | "socks5h" => {
                    settings.all = normalize_proxy_url(address, scheme_lower.as_str());
                }
                _ => {}
            }
        }
    } else {
        let normalized = normalize_proxy_url(server, "http");
        settings.http = normalized.clone();
        settings.https = normalized;
    }

    settings.bypass = bypass.map(parse_bypass_list).unwrap_or_default();
    dedup_bypass(&mut settings);
    settings
}

fn parse_bypass_list(value: &str) -> Vec<String> {
    value
        .split([',', ';', '|'])
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(|item| item.to_string())
        .collect()
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

#[cfg(target_os = "windows")]
mod registry {
    use super::*;

    pub(super) fn current_proxy_settings() -> ProxySettings {
        const SUB_KEY: &str = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";

        let hkcu = RegKey::predef(enums::HKEY_CURRENT_USER);
        let key = match hkcu.open_subkey_with_flags(SUB_KEY, enums::KEY_READ) {
            Ok(key) => key,
            Err(_) => return ProxySettings::default(),
        };

        if key.get_value::<u32, _>("ProxyEnable").ok() != Some(1) {
            return ProxySettings::default();
        }

        let server = match key.get_value::<String, _>("ProxyServer") {
            Ok(value) => value,
            Err(_) => return ProxySettings::default(),
        };
        let bypass = key.get_value::<String, _>("ProxyOverride").ok();

        proxy_settings_from_proxy_server(&server, bypass.as_deref())
    }
}
