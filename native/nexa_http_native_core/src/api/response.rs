use crate::api::request::NativeHttpHeader;
use reqwest::Response;
use std::ptr::{null_mut, slice_from_raw_parts_mut};

#[derive(Debug)]
pub(crate) struct NativeHttpOwnedBytes {
    bytes: Box<[u8]>,
}

impl NativeHttpOwnedBytes {
    pub(crate) fn from_bytes(bytes: &[u8]) -> Self {
        Self {
            // The FFI ABI only tracks a pointer and length, so use a boxed
            // slice with a single explicit owner for the native byte buffer.
            bytes: bytes.to_vec().into_boxed_slice(),
        }
    }

    pub(crate) fn into_raw_parts(self) -> (*mut u8, usize) {
        let len = self.bytes.len();
        if len == 0 {
            return (null_mut(), 0);
        }

        let ptr = Box::into_raw(self.bytes).cast::<u8>();
        (ptr, len)
    }

    pub(crate) unsafe fn free_raw_parts(ptr: *mut u8, len: usize) {
        if ptr.is_null() || len == 0 {
            return;
        }

        drop(unsafe { Box::from_raw(slice_from_raw_parts_mut(ptr, len)) });
    }
}

#[derive(Debug)]
pub(crate) struct NativeHttpPendingResponse {
    pub(crate) status_code: u16,
    pub(crate) headers: Vec<NativeHttpHeader>,
    pub(crate) final_url: Option<String>,
    pub(crate) response: Response,
}
