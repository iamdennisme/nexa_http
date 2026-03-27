use std::ffi::c_char;

#[repr(C)]
pub struct NexaHttpBinaryResult {
    pub is_success: u8,
    pub status_code: u16,
    pub headers_json: *mut c_char,
    pub final_url: *mut c_char,
    pub body_ptr: *mut u8,
    pub body_len: usize,
    pub error_json: *mut c_char,
}

pub type NexaHttpExecuteCallback = Option<unsafe extern "C" fn(u64, *mut NexaHttpBinaryResult)>;
