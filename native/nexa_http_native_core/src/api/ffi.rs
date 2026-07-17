use crate::api::error::{NativeError, NativeHttpError};
use crate::api::response::NativeHttpOwnedBody;
use std::collections::HashMap;
use std::ffi::{CString, c_char};
use std::ptr::null_mut;
use std::sync::{LazyLock, Mutex};

pub use crate::api::ffi_types::{
    NexaHttpBinaryResult, NexaHttpClientConfigArgs, NexaHttpExecuteCallback, NexaHttpHeaderEntry,
    NexaHttpRequestArgs,
};

static TEST_BINARY_RESULT_FREE_COUNTS: LazyLock<Mutex<HashMap<usize, usize>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static LAST_ERROR_JSON: LazyLock<Mutex<Option<String>>> = LazyLock::new(|| Mutex::new(None));

pub(crate) fn track_test_binary_result(value: *mut NexaHttpBinaryResult) {
    TEST_BINARY_RESULT_FREE_COUNTS
        .lock()
        .unwrap()
        .insert(value as usize, 0);
}

pub(crate) fn record_test_binary_result_free(value: *mut NexaHttpBinaryResult) -> bool {
    let mut tracked = TEST_BINARY_RESULT_FREE_COUNTS.lock().unwrap();
    let count = tracked.entry(value as usize).or_insert(0);
    *count += 1;
    *count == 1
}

pub(crate) fn clear_last_error_json() {
    *LAST_ERROR_JSON.lock().unwrap() = None;
}

pub(crate) fn store_bootstrap_error(stage: &'static str, error: NativeError) {
    let mut details = error.details.unwrap_or_default();
    details.insert("stage".to_string(), stage.to_string());
    details.insert("native_code".to_string(), error.code.to_string());
    details.insert("native_message".to_string(), error.message.clone());

    let serialized = serde_json::to_string(&NativeHttpError {
        code: "native_bootstrap_failed".to_string(),
        message: "The nexa_http native bootstrap failed.".to_string(),
        status_code: None,
        is_timeout: false,
        uri: None,
        details: Some(details),
    })
    .unwrap_or_else(|_| {
        r#"{"code":"native_bootstrap_failed","message":"The nexa_http native bootstrap failed.","is_timeout":false,"details":{"stage":"serialization"}} "#.trim().to_string()
    });
    *LAST_ERROR_JSON.lock().unwrap() = Some(serialized);
}

pub fn take_last_error_json() -> *mut c_char {
    let last_error = LAST_ERROR_JSON.lock().unwrap().take();
    match last_error.and_then(|json| CString::new(json).ok()) {
        Some(value) => value.into_raw(),
        None => null_mut(),
    }
}

/// Releases a string previously returned by the native API.
///
/// # Safety
///
/// `value` must be null or a pointer returned by `CString::into_raw` from this
/// library, and it must not have been released before.
pub unsafe fn string_free(value: *mut c_char) {
    if value.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(value));
    }
}

/// Creates a test result by copying `body_len` bytes from `body_ptr`.
///
/// # Safety
///
/// When `body_len` is non-zero, `body_ptr` must reference at least that many
/// readable bytes for the duration of this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn nexa_http_test_binary_result_new_success(
    body_ptr: *const u8,
    body_len: usize,
    invalid_final_url: u8,
) -> *mut NexaHttpBinaryResult {
    let mut result = NexaHttpBinaryResult {
        is_success: 1,
        status_code: 200,
        headers_ptr: null_mut(),
        headers_len: 0,
        final_url_ptr: null_mut(),
        final_url_len: 0,
        body_ptr: null_mut(),
        body_len: 0,
        body_owner: null_mut(),
        error_json: null_mut(),
    };
    let body = if body_ptr.is_null() || body_len == 0 {
        NativeHttpOwnedBody::from_bytes(&[])
    } else {
        let bytes = unsafe { std::slice::from_raw_parts(body_ptr, body_len) };
        NativeHttpOwnedBody::from_bytes(bytes)
    };
    result.set_owned_body(body);

    if invalid_final_url == 0 {
        let final_url = CString::new("https://example.com/native-test-result").unwrap();
        result.final_url_len = final_url.as_bytes().len();
        result.final_url_ptr = final_url.into_raw();
    } else {
        result.final_url_ptr = null_mut();
        result.final_url_len = 1;
    }

    let result = Box::into_raw(Box::new(result));
    track_test_binary_result(result);
    result
}

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_binary_result_free_count(
    value: *mut NexaHttpBinaryResult,
) -> usize {
    TEST_BINARY_RESULT_FREE_COUNTS
        .lock()
        .unwrap()
        .get(&(value as usize))
        .copied()
        .unwrap_or(0)
}

/// Releases a test result returned by this library.
///
/// # Safety
///
/// `value` must be null or a live result pointer returned by this library.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn nexa_http_test_binary_result_free(value: *mut NexaHttpBinaryResult) {
    if value.is_null() {
        return;
    }
    if record_test_binary_result_free(value) {
        unsafe {
            crate::api::ffi_result::free_binary_result(value);
        }
    }
}
