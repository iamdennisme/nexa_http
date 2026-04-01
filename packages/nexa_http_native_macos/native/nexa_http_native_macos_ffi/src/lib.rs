mod proxy_source;

use nexa_http_native_core::api::ffi::{
    NexaHttpBinaryResult, NexaHttpExecuteCallback, NexaHttpRequestArgs,
};
use nexa_http_native_core::runtime::{ManagedProxyState, NexaHttpRuntime};
use once_cell::sync::Lazy;
use std::ffi::c_char;

pub use proxy_source::{MacosProxySource, current_proxy_settings_for_test};

static RUNTIME: Lazy<NexaHttpRuntime<ManagedProxyState<MacosProxySource>>> = Lazy::new(|| {
    NexaHttpRuntime::new(ManagedProxyState::with_background_refresh(
        MacosProxySource::new(),
        "nexa-http-macos-proxy".to_string(),
    ))
});

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
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_binary_result_free(value: *mut NexaHttpBinaryResult) {
    NexaHttpRuntime::<ManagedProxyState<MacosProxySource>>::binary_result_free(value);
}
