use nexa_http_native_core::api::ffi::{NexaHttpBinaryResult, NexaHttpExecuteCallback};
use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use once_cell::sync::Lazy;
use reqwest::Url;
use std::collections::BTreeSet;
use std::ffi::c_char;

struct MacosPlatformCapabilities;

impl PlatformCapabilities for MacosPlatformCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        current_proxy_settings()
    }
}

static RUNTIME: Lazy<NexaHttpRuntime<MacosPlatformCapabilities>> =
    Lazy::new(|| NexaHttpRuntime::new(MacosPlatformCapabilities));

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_create(config_json: *const c_char) -> u64 {
    RUNTIME.create_client(config_json)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_execute_async(
    client_id: u64,
    request_id: u64,
    request_json: *const c_char,
    body_ptr: *const u8,
    body_len: usize,
    callback: NexaHttpExecuteCallback,
) -> u8 {
    RUNTIME.execute_async(
        client_id,
        request_id,
        request_json,
        body_ptr,
        body_len,
        callback,
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_execute_binary(
    client_id: u64,
    request_json: *const c_char,
    body_ptr: *const u8,
    body_len: usize,
) -> *mut NexaHttpBinaryResult {
    RUNTIME.execute_binary(client_id, request_json, body_ptr, body_len)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_binary_result_free(value: *mut NexaHttpBinaryResult) {
    NexaHttpRuntime::<MacosPlatformCapabilities>::binary_result_free(value);
}

pub fn current_proxy_settings_for_test(
    http_enabled: bool,
    http_host: Option<&str>,
    http_port: Option<i32>,
    https_enabled: bool,
    https_host: Option<&str>,
    https_port: Option<i32>,
    socks_enabled: bool,
    socks_host: Option<&str>,
    socks_port: Option<i32>,
    exceptions: Vec<String>,
    exclude_simple_hostnames: bool,
) -> ProxySettings {
    proxy_settings_from_apple_values(
        http_enabled,
        http_host,
        http_port,
        https_enabled,
        https_host,
        https_port,
        socks_enabled,
        socks_host,
        socks_port,
        exceptions,
        exclude_simple_hostnames,
    )
}

fn current_proxy_settings() -> ProxySettings {
    #[cfg(target_os = "macos")]
    {
        sysconfig::current_proxy_settings()
    }

    #[cfg(not(target_os = "macos"))]
    {
        ProxySettings::default()
    }
}

fn proxy_settings_from_apple_values(
    http_enabled: bool,
    http_host: Option<&str>,
    http_port: Option<i32>,
    https_enabled: bool,
    https_host: Option<&str>,
    https_port: Option<i32>,
    socks_enabled: bool,
    socks_host: Option<&str>,
    socks_port: Option<i32>,
    mut exceptions: Vec<String>,
    exclude_simple_hostnames: bool,
) -> ProxySettings {
    let http = apple_entry(http_enabled, http_host, http_port, "http");
    let https = apple_entry(https_enabled, https_host, https_port, "http");
    let all = apple_entry(socks_enabled, socks_host, socks_port, "socks5");

    if exclude_simple_hostnames {
        exceptions.push("<local>".to_string());
    }

    let mut settings = ProxySettings {
        http,
        https,
        all,
        bypass: exceptions,
    };
    dedup_bypass(&mut settings);
    settings
}

fn apple_entry(enabled: bool, host: Option<&str>, port: Option<i32>, scheme: &str) -> Option<String> {
    if !enabled {
        return None;
    }
    let host = host?.trim();
    if host.is_empty() {
        return None;
    }

    let host_port = match port.filter(|value| *value > 0) {
        Some(port) => format!("{host}:{port}"),
        None => host.to_string(),
    };
    normalize_proxy_url(&host_port, scheme)
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

#[cfg(target_os = "macos")]
mod sysconfig {
    use super::*;
    use core_foundation::array::{CFArray, CFArrayRef};
    use core_foundation::base::{CFRelease, TCFType};
    use core_foundation::dictionary::{CFDictionaryGetValue, CFDictionaryRef};
    use core_foundation::number::{CFNumberGetValue, CFNumberRef, kCFNumberSInt32Type};
    use core_foundation::string::{CFString, CFStringRef};
    use std::ffi::c_void;
    use std::ptr;
    use system_configuration_sys::dynamic_store_copy_specific::SCDynamicStoreCopyProxies;
    use system_configuration_sys::schema_definitions::{
        kSCPropNetProxiesExceptionsList, kSCPropNetProxiesExcludeSimpleHostnames,
        kSCPropNetProxiesHTTPEnable, kSCPropNetProxiesHTTPPort, kSCPropNetProxiesHTTPProxy,
        kSCPropNetProxiesHTTPSEnable, kSCPropNetProxiesHTTPSPort, kSCPropNetProxiesHTTPSProxy,
        kSCPropNetProxiesSOCKSEnable, kSCPropNetProxiesSOCKSPort, kSCPropNetProxiesSOCKSProxy,
    };

    pub(super) fn current_proxy_settings() -> ProxySettings {
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
            return ProxySettings::default();
        }
        let proxies = ProxiesRef(proxies);

        let http_enabled = dictionary_bool(proxies.0, unsafe { kSCPropNetProxiesHTTPEnable });
        let http_host = dictionary_string(proxies.0, unsafe { kSCPropNetProxiesHTTPProxy });
        let http_port = dictionary_i32(proxies.0, unsafe { kSCPropNetProxiesHTTPPort });

        let https_enabled = dictionary_bool(proxies.0, unsafe { kSCPropNetProxiesHTTPSEnable });
        let https_host = dictionary_string(proxies.0, unsafe { kSCPropNetProxiesHTTPSProxy });
        let https_port = dictionary_i32(proxies.0, unsafe { kSCPropNetProxiesHTTPSPort });

        let socks_enabled = dictionary_bool(proxies.0, unsafe { kSCPropNetProxiesSOCKSEnable });
        let socks_host = dictionary_string(proxies.0, unsafe { kSCPropNetProxiesSOCKSProxy });
        let socks_port = dictionary_i32(proxies.0, unsafe { kSCPropNetProxiesSOCKSPort });

        let exceptions = dictionary_string_array(proxies.0, unsafe { kSCPropNetProxiesExceptionsList });
        let exclude_simple = dictionary_bool(proxies.0, unsafe { kSCPropNetProxiesExcludeSimpleHostnames });

        proxy_settings_from_apple_values(
            http_enabled,
            http_host.as_deref(),
            http_port,
            https_enabled,
            https_host.as_deref(),
            https_port,
            socks_enabled,
            socks_host.as_deref(),
            socks_port,
            exceptions,
            exclude_simple,
        )
    }

    fn dictionary_value(proxies: CFDictionaryRef, key: CFStringRef) -> *const c_void {
        unsafe { CFDictionaryGetValue(proxies, key as *const c_void) }
    }

    fn dictionary_i32(proxies: CFDictionaryRef, key: CFStringRef) -> Option<i32> {
        let value = dictionary_value(proxies, key);
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

    fn dictionary_bool(proxies: CFDictionaryRef, key: CFStringRef) -> bool {
        dictionary_i32(proxies, key).unwrap_or(0) == 1
    }

    fn dictionary_string(proxies: CFDictionaryRef, key: CFStringRef) -> Option<String> {
        let value = dictionary_value(proxies, key);
        if value.is_null() {
            return None;
        }
        clean_value(unsafe { CFString::wrap_under_get_rule(value as CFStringRef) }.to_string())
    }

    fn dictionary_string_array(proxies: CFDictionaryRef, key: CFStringRef) -> Vec<String> {
        let value = dictionary_value(proxies, key);
        if value.is_null() {
            return Vec::new();
        }

        let array = unsafe { CFArray::<CFString>::wrap_under_get_rule(value as CFArrayRef) };
        array
            .iter()
            .filter_map(|item| clean_value(item.to_string()))
            .collect()
    }
}
