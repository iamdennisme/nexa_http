mod proxy_source;

use nexa_http_native_core::api::ffi::{
    NexaHttpBinaryResult, NexaHttpClientConfigArgs, NexaHttpExecuteCallback, NexaHttpRequestArgs,
    string_free, take_last_error_json,
};
use std::ffi::c_char;
use nexa_http_native_core::runtime::{ManagedProxyState, NexaHttpRuntime};
use once_cell::sync::Lazy;

pub use proxy_source::{IosProxySource, current_proxy_settings_for_test};

static RUNTIME: Lazy<NexaHttpRuntime<ManagedProxyState<IosProxySource>>> =
    Lazy::new(|| NexaHttpRuntime::new(ManagedProxyState::new(IosProxySource::new())));

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_create(config_args: *const NexaHttpClientConfigArgs) -> u64 {
    RUNTIME.create_client(config_args)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_take_last_error_json() -> *mut c_char {
    take_last_error_json()
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_string_free(value: *mut c_char) {
    unsafe { string_free(value) };
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_request_body_alloc(body_len: usize) -> *mut u8 {
    NexaHttpRuntime::<ManagedProxyState<IosProxySource>>::request_body_alloc(body_len)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_request_body_free(body_ptr: *mut u8, body_len: usize) {
    NexaHttpRuntime::<ManagedProxyState<IosProxySource>>::request_body_free(body_ptr, body_len);
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
pub extern "C" fn nexa_http_client_cancel_request(client_id: u64, request_id: u64) -> u8 {
    RUNTIME.cancel_request(client_id, request_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_binary_result_free(value: *mut NexaHttpBinaryResult) {
    NexaHttpRuntime::<ManagedProxyState<IosProxySource>>::binary_result_free(value);
}
