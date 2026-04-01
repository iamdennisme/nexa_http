use bytes::Bytes;
use std::ffi::c_void;
use crate::api::request::NativeHttpHeader;
use std::ptr::null_mut;

#[derive(Debug)]
pub(crate) struct NativeHttpOwnedBody {
    bytes: Bytes,
}

impl NativeHttpOwnedBody {
    pub(crate) fn from_bytes(bytes: &[u8]) -> Self {
        Self {
            bytes: Bytes::copy_from_slice(bytes),
        }
    }

    pub(crate) fn from_response_bytes(bytes: Bytes) -> Self {
        Self { bytes }
    }

    pub(crate) fn into_raw_parts(self) -> (*mut u8, usize, *mut c_void) {
        let len = self.bytes.len();
        if len == 0 {
            return (null_mut(), 0, null_mut());
        }

        let ptr = self.bytes.as_ptr().cast_mut();
        let owner = Box::into_raw(Box::new(self.bytes)).cast::<c_void>();
        (ptr, len, owner)
    }

    pub(crate) unsafe fn free_raw_parts(_ptr: *mut u8, _len: usize, owner: *mut c_void) {
        if owner.is_null() {
            return;
        }

        drop(unsafe { Box::from_raw(owner.cast::<Bytes>()) });
    }
}

#[derive(Debug)]
pub(crate) struct NativeHttpRawResponse {
    pub(crate) status_code: u16,
    pub(crate) headers: Vec<NativeHttpHeader>,
    pub(crate) body: NativeHttpOwnedBody,
    pub(crate) final_url: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn response_body_owner_reuses_existing_bytes_buffer() {
        let bytes = Bytes::from_static(b"hello");
        let expected_ptr = bytes.as_ptr();
        let body = NativeHttpOwnedBody::from_response_bytes(bytes);

        let (body_ptr, body_len, body_owner) = body.into_raw_parts();

        assert_eq!(body_ptr.cast_const(), expected_ptr);
        assert_eq!(body_len, 5);

        unsafe {
            NativeHttpOwnedBody::free_raw_parts(body_ptr, body_len, body_owner);
        }
    }
}
