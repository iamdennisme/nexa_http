use nexa_http_native_core::platform::{ProxyConfigSource, ProxySettings, RefreshMode};
use reqwest::Url;
use std::collections::BTreeSet;
#[derive(Clone, Debug, Default)]
pub struct IosProxySource;

impl IosProxySource {
    pub fn new() -> Self {
        Self
    }
}

impl ProxyConfigSource for IosProxySource {
    fn load_current(&self) -> ProxySettings {
        current_proxy_settings()
    }

    fn refresh_mode(&self) -> RefreshMode {
        RefreshMode::ConstructionBoundary
    }
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
    #[cfg(any(target_os = "ios", target_os = "macos"))]
    {
        sysconfig::current_proxy_settings()
    }

    #[cfg(not(any(target_os = "ios", target_os = "macos")))]
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

fn apple_entry(
    enabled: bool,
    host: Option<&str>,
    port: Option<i32>,
    scheme: &str,
) -> Option<String> {
    if !enabled {
        return None;
    }
    let host = clean_value(host?.to_string())?;

    let host_port = match port.filter(|value| *value > 0) {
        Some(port) => format!("{host}:{port}"),
        None => host.to_string(),
    };
    normalize_proxy_url(&host_port, scheme)
}

fn dedup_bypass(settings: &mut ProxySettings) {
    let mut set = BTreeSet::<String>::new();
    for item in &settings.bypass {
        if let Some(trimmed) = clean_value(item.to_string()) {
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

#[cfg(any(target_os = "ios", target_os = "macos"))]
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

        let exceptions =
            dictionary_string_array(proxies.0, unsafe { kSCPropNetProxiesExceptionsList });
        let exclude_simple = dictionary_bool(proxies.0, unsafe {
            kSCPropNetProxiesExcludeSimpleHostnames
        });

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

    fn dictionary_bool(dictionary: CFDictionaryRef, key: CFStringRef) -> bool {
        dictionary_i32(dictionary, key).is_some_and(|value| value != 0)
    }

    fn dictionary_i32(dictionary: CFDictionaryRef, key: CFStringRef) -> Option<i32> {
        let key_ref = key as *const std::ffi::c_void;
        let value = unsafe { CFDictionaryGetValue(dictionary, key_ref) };
        if value.is_null() {
            return None;
        }

        let mut number = 0i32;
        let ok = unsafe {
            CFNumberGetValue(
                value.cast::<std::ffi::c_void>() as CFNumberRef,
                kCFNumberSInt32Type,
                (&mut number as *mut i32).cast(),
            )
        };
        if ok { Some(number) } else { None }
    }

    fn dictionary_string(dictionary: CFDictionaryRef, key: CFStringRef) -> Option<String> {
        let key_ref = key as *const std::ffi::c_void;
        let value = unsafe { CFDictionaryGetValue(dictionary, key_ref) };
        if value.is_null() {
            return None;
        }
        let value = unsafe { CFString::wrap_under_get_rule(value.cast()) };
        clean_value(value.to_string())
    }

    fn dictionary_string_array(dictionary: CFDictionaryRef, key: CFStringRef) -> Vec<String> {
        let key_ref = key as *const std::ffi::c_void;
        let value = unsafe { CFDictionaryGetValue(dictionary, key_ref) };
        if value.is_null() {
            return Vec::new();
        }

        let array = unsafe { CFArray::<CFString>::wrap_under_get_rule(value as CFArrayRef) };
        array
            .iter()
            .filter_map(|item| clean_value(item.to_string()))
            .collect::<Vec<_>>()
    }
}
