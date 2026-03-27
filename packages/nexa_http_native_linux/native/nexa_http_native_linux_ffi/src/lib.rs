use nexa_http_native_core::api::ffi::{NexaHttpBinaryResult, NexaHttpExecuteCallback};
use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;
use once_cell::sync::Lazy;
use std::ffi::c_char;

struct LinuxPlatformCapabilities;

impl PlatformCapabilities for LinuxPlatformCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        ProxySettings::default()
    }
}

static RUNTIME: Lazy<NexaHttpRuntime<LinuxPlatformCapabilities>> =
    Lazy::new(|| NexaHttpRuntime::new(LinuxPlatformCapabilities));

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
    NexaHttpRuntime::<LinuxPlatformCapabilities>::binary_result_free(value);
}

pub fn current_proxy_settings_for_test() -> ProxySettings {
    ProxySettings::default()
}
