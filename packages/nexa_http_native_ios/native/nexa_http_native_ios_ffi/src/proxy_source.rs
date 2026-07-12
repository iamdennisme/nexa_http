use nexa_http_native_apple_proxy::{
    AppleProxyEntry, AppleProxySettings, parse_apple_proxy_settings,
};
use nexa_http_native_core::platform::{ProxyConfigSource, ProxySettings, RefreshMode};
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

pub fn current_proxy_settings_for_test(values: AppleProxySettings) -> ProxySettings {
    parse_apple_proxy_settings(values)
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

        parse_apple_proxy_settings(AppleProxySettings {
            http: AppleProxyEntry {
                enabled: http_enabled,
                host: http_host,
                port: http_port,
            },
            https: AppleProxyEntry {
                enabled: https_enabled,
                host: https_host,
                port: https_port,
            },
            socks: AppleProxyEntry {
                enabled: socks_enabled,
                host: socks_host,
                port: socks_port,
            },
            exceptions,
            exclude_simple_hostnames: exclude_simple,
        })
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
        Some(value.to_string())
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
            .map(|item| item.to_string())
            .collect::<Vec<_>>()
    }
}
