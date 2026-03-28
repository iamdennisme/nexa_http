use crate::api::response::NativeHttpOwnedBody;
use std::collections::HashMap;
use std::ffi::{CString, c_char};
use std::ptr::null_mut;
use std::sync::{LazyLock, Mutex};

#[repr(C)]
pub struct NexaHttpHeaderEntry {
    pub name_ptr: *const c_char,
    pub name_len: usize,
    pub value_ptr: *const c_char,
    pub value_len: usize,
}

#[repr(C)]
pub struct NexaHttpRequestArgs {
    pub method_ptr: *const c_char,
    pub method_len: usize,
    pub url_ptr: *const c_char,
    pub url_len: usize,
    pub headers_ptr: *const NexaHttpHeaderEntry,
    pub headers_len: usize,
    pub body_ptr: *const u8,
    pub body_len: usize,
    pub timeout_ms: u64,
    pub has_timeout: u8,
}

#[repr(C)]
pub struct NexaHttpBinaryResult {
    pub is_success: u8,
    pub status_code: u16,
    pub headers_ptr: *mut NexaHttpHeaderEntry,
    pub headers_len: usize,
    pub final_url_ptr: *mut c_char,
    pub final_url_len: usize,
    pub body_ptr: *mut u8,
    pub body_len: usize,
    pub error_json: *mut c_char,
}

pub type NexaHttpExecuteCallback = Option<unsafe extern "C" fn(u64, *mut NexaHttpBinaryResult)>;

static TEST_BINARY_RESULT_FREE_COUNTS: LazyLock<Mutex<HashMap<usize, usize>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

impl NexaHttpBinaryResult {
    pub(crate) fn set_owned_body(&mut self, body: NativeHttpOwnedBody) {
        let (body_ptr, body_len) = body.into_raw_parts();
        self.body_ptr = body_ptr;
        self.body_len = body_len;
    }

    pub(crate) unsafe fn free_owned_body(&mut self) {
        unsafe {
            NativeHttpOwnedBody::free_raw_parts(self.body_ptr, self.body_len);
        }
        self.body_ptr = null_mut();
        self.body_len = 0;
    }
}

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

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_binary_result_new_success(
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

#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_test_binary_result_free(value: *mut NexaHttpBinaryResult) {
    if value.is_null() {
        return;
    }
    if record_test_binary_result_free(value) {
        unsafe {
            crate::runtime::executor::binary_result_free_impl(value);
        }
    }
}
