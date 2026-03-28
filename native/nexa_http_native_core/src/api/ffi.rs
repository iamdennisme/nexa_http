use std::ffi::c_char;

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
