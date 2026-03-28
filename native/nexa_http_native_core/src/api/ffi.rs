use crate::api::response::NativeHttpOwnedBody;
use std::ffi::c_char;
use std::ptr::null_mut;

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
