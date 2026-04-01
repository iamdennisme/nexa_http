use std::collections::HashMap;
use std::ptr::null_mut;

#[derive(Debug, Clone)]
pub(crate) struct NativeHttpHeader {
    pub(crate) name: String,
    pub(crate) value: String,
}

#[derive(Debug, Clone, Default, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct NativeHttpClientConfig {
    pub(crate) default_headers: HashMap<String, String>,
    pub(crate) timeout_ms: Option<u64>,
    pub(crate) user_agent: Option<String>,
}

#[derive(Debug, Clone)]
pub(crate) struct NativeHttpRequest {
    pub(crate) method: String,
    pub(crate) url: String,
    pub(crate) headers: Vec<NativeHttpHeader>,
    pub(crate) body: Vec<u8>,
    pub(crate) timeout_ms: Option<u64>,
}

pub(crate) struct NativeHttpOwnedRequestBody;

impl NativeHttpOwnedRequestBody {
    pub(crate) fn alloc_raw_parts(len: usize) -> *mut u8 {
        if len == 0 {
            return null_mut();
        }

        let mut body = vec![0u8; len];
        let ptr = body.as_mut_ptr();
        std::mem::forget(body);
        ptr
    }

    pub(crate) unsafe fn into_vec(ptr: *mut u8, len: usize) -> Vec<u8> {
        if ptr.is_null() || len == 0 {
            return Vec::new();
        }

        unsafe { Vec::from_raw_parts(ptr, len, len) }
    }

    pub(crate) unsafe fn free_raw_parts(ptr: *mut u8, len: usize) {
        if ptr.is_null() || len == 0 {
            return;
        }

        drop(unsafe { Vec::from_raw_parts(ptr, len, len) });
    }
}
