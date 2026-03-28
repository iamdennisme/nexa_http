use nexa_http_native_core::api::ffi::{
    NexaHttpExecuteCallback, NexaHttpRequestArgs, NexaHttpResponseChunkResult,
    NexaHttpResponseHeadResult,
};
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
    NexaHttpRuntime::<LinuxPlatformCapabilities>::response_head_result_free(value);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_response_chunk_result_free(value: *mut NexaHttpResponseChunkResult) {
    NexaHttpRuntime::<LinuxPlatformCapabilities>::response_chunk_result_free(value);
}

pub fn current_proxy_settings_for_test() -> ProxySettings {
    ProxySettings::default()
}
