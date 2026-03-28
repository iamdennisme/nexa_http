use nexa_http_native_core::api::ffi::{
    NexaHttpExecuteCallback, NexaHttpHeaderEntry, NexaHttpRequestArgs, NexaHttpResponseChunkResult,
    NexaHttpResponseHeadResult,
};
use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use once_cell::sync::Lazy;
use reqwest::Url;
use std::collections::{BTreeSet, HashMap};
use std::ffi::{c_char, CString};
use std::ptr::null_mut;
use std::sync::Mutex;

struct MacosPlatformCapabilities;

impl PlatformCapabilities for MacosPlatformCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        current_proxy_settings()
    }
}

static RUNTIME: Lazy<NexaHttpRuntime<MacosPlatformCapabilities>> =
    Lazy::new(|| NexaHttpRuntime::new(MacosPlatformCapabilities));
static TEST_RESPONSE_HEAD_FREE_COUNTS: Lazy<Mutex<HashMap<usize, usize>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static TEST_RESPONSE_CHUNK_FREE_COUNTS: Lazy<Mutex<HashMap<usize, usize>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

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
) -> *mut NexaHttpResponseHeadResult {
    RUNTIME.execute_binary(client_id, request_args)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_response_stream_next(
    stream_id: u64,
) -> *mut NexaHttpResponseChunkResult {
    RUNTIME.response_stream_next(stream_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_response_stream_close(stream_id: u64) {
    RUNTIME.close_response_stream(stream_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_response_head_result_free(value: *mut NexaHttpResponseHeadResult) {
    if should_free_tracked_pointer(&TEST_RESPONSE_HEAD_FREE_COUNTS, value.cast()) {
        NexaHttpRuntime::<MacosPlatformCapabilities>::response_head_result_free(value);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_response_chunk_result_free(value: *mut NexaHttpResponseChunkResult) {
    if should_free_tracked_pointer(&TEST_RESPONSE_CHUNK_FREE_COUNTS, value.cast()) {
        NexaHttpRuntime::<MacosPlatformCapabilities>::response_chunk_result_free(value);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_response_head_result_new_success(
    stream_id: u64,
) -> *mut NexaHttpResponseHeadResult {
    let (headers_ptr, headers_len) = build_test_header_entries(&[
        ("content-type", "application/octet-stream"),
        ("cache-control", "max-age=60"),
    ]);
    let final_url = CString::new("https://example.com/native-stream-result").unwrap();
    let final_url_len = final_url.as_bytes().len();
    let result = Box::into_raw(Box::new(NexaHttpResponseHeadResult {
        is_success: 1,
        status_code: 200,
        headers_ptr,
        headers_len,
        final_url_ptr: final_url.into_raw(),
        final_url_len,
        stream_id,
        error_json: null_mut(),
    }));
    track_test_pointer(&TEST_RESPONSE_HEAD_FREE_COUNTS, result.cast());
    result
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_response_head_result_free_count(
    value: *mut NexaHttpResponseHeadResult,
) -> usize {
    tracked_pointer_free_count(&TEST_RESPONSE_HEAD_FREE_COUNTS, value.cast())
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_response_chunk_result_new_success(
    chunk_ptr: *const u8,
    chunk_len: usize,
) -> *mut NexaHttpResponseChunkResult {
    let (chunk_ptr, chunk_len) = clone_chunk_bytes(chunk_ptr, chunk_len);
    let result = Box::into_raw(Box::new(NexaHttpResponseChunkResult {
        is_success: 1,
        is_done: 0,
        chunk_ptr,
        chunk_len,
        error_json: null_mut(),
    }));
    track_test_pointer(&TEST_RESPONSE_CHUNK_FREE_COUNTS, result.cast());
    result
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_response_chunk_result_new_done() -> *mut NexaHttpResponseChunkResult
{
    let result = Box::into_raw(Box::new(NexaHttpResponseChunkResult {
        is_success: 1,
        is_done: 1,
        chunk_ptr: null_mut(),
        chunk_len: 0,
        error_json: null_mut(),
    }));
    track_test_pointer(&TEST_RESPONSE_CHUNK_FREE_COUNTS, result.cast());
    result
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_response_chunk_result_free_count(
    value: *mut NexaHttpResponseChunkResult,
) -> usize {
    tracked_pointer_free_count(&TEST_RESPONSE_CHUNK_FREE_COUNTS, value.cast())
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

fn track_test_pointer(
    registry: &Lazy<Mutex<HashMap<usize, usize>>>,
    pointer: *mut std::ffi::c_void,
) {
    registry.lock().unwrap().insert(pointer as usize, 0);
}

fn should_free_tracked_pointer(
    registry: &Lazy<Mutex<HashMap<usize, usize>>>,
    pointer: *mut std::ffi::c_void,
) -> bool {
    if pointer.is_null() {
        return false;
    }

    let mut tracked = registry.lock().unwrap();
    match tracked.get_mut(&(pointer as usize)) {
        Some(count) => {
            *count += 1;
            *count == 1
        }
        None => true,
    }
}

fn tracked_pointer_free_count(
    registry: &Lazy<Mutex<HashMap<usize, usize>>>,
    pointer: *mut std::ffi::c_void,
) -> usize {
    registry
        .lock()
        .unwrap()
        .get(&(pointer as usize))
        .copied()
        .unwrap_or(0)
}

fn build_test_header_entries(headers: &[(&str, &str)]) -> (*mut NexaHttpHeaderEntry, usize) {
    if headers.is_empty() {
        return (null_mut(), 0);
    }

    let mut entries = Vec::<NexaHttpHeaderEntry>::with_capacity(headers.len());
    for (name, value) in headers {
        let name = CString::new(*name).unwrap();
        let value = CString::new(*value).unwrap();
        let name_len = name.as_bytes().len();
        let value_len = value.as_bytes().len();
        entries.push(NexaHttpHeaderEntry {
            name_ptr: name.into_raw(),
            name_len,
            value_ptr: value.into_raw(),
            value_len,
        });
    }

    let len = entries.len();
    let ptr = entries.as_mut_ptr();
    std::mem::forget(entries);
    (ptr, len)
}

fn clone_chunk_bytes(chunk_ptr: *const u8, chunk_len: usize) -> (*mut u8, usize) {
    if chunk_ptr.is_null() || chunk_len == 0 {
        return (null_mut(), 0);
    }

    let bytes = unsafe { std::slice::from_raw_parts(chunk_ptr, chunk_len) }
        .to_vec()
        .into_boxed_slice();
    let ptr = Box::into_raw(bytes).cast::<u8>();
    (ptr, chunk_len)
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
