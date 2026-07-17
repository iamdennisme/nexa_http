use crate::api::error::NativeHttpError;
use crate::api::ffi_types::{NexaHttpBinaryResult, NexaHttpHeaderEntry};
use crate::api::request::NativeHttpHeader;
use crate::api::response::NativeHttpRawResponse;
use std::ffi::{CString, c_char};
use std::ptr::null_mut;

pub(crate) fn build_binary_success_result(response: NativeHttpRawResponse) -> NexaHttpBinaryResult {
    let (headers_ptr, headers_len) = match build_header_entries_buffer(response.headers) {
        Ok(value) => value,
        Err(error) => return build_binary_error_result(*error),
    };
    let (final_url_ptr, final_url_len) = match build_string_buffer(response.final_url) {
        Ok(value) => value,
        Err(error) => {
            free_header_entries_buffer(headers_ptr, headers_len);
            return build_binary_error_result(*error);
        }
    };

    let mut result = NexaHttpBinaryResult {
        is_success: 1,
        status_code: response.status_code,
        headers_ptr,
        headers_len,
        final_url_ptr,
        final_url_len,
        body_ptr: null_mut(),
        body_len: 0,
        body_owner: null_mut(),
        error_json: null_mut(),
    };
    result.set_owned_body(response.body);
    result
}

pub(crate) fn build_binary_error_result(error: NativeHttpError) -> NexaHttpBinaryResult {
    let error_json = match serde_json::to_string(&error)
        .ok()
        .and_then(|json| CString::new(json).ok())
    {
        Some(value) => value.into_raw(),
        None => CString::new(
            r#"{"code":"serialization","message":"Failed to encode error.","is_timeout":false}"#,
        )
        .unwrap()
        .into_raw(),
    };

    NexaHttpBinaryResult {
        is_success: 0,
        status_code: 0,
        headers_ptr: null_mut(),
        headers_len: 0,
        final_url_ptr: null_mut(),
        final_url_len: 0,
        body_ptr: null_mut(),
        body_len: 0,
        body_owner: null_mut(),
        error_json,
    }
}

/// Releases all allocations owned by one binary result.
///
/// # Safety
///
/// `value` must be null or a live pointer returned by this crate, and the same
/// result must not be released more than once.
pub(crate) unsafe fn free_binary_result(value: *mut NexaHttpBinaryResult) {
    if value.is_null() {
        return;
    }

    unsafe {
        let mut result = Box::from_raw(value);
        free_header_entries_buffer(result.headers_ptr, result.headers_len);
        if !result.final_url_ptr.is_null() {
            drop(CString::from_raw(result.final_url_ptr));
        }
        if !result.error_json.is_null() {
            drop(CString::from_raw(result.error_json));
        }
        result.free_owned_body();
    }
}

fn build_header_entries_buffer(
    headers: Vec<NativeHttpHeader>,
) -> Result<(*mut NexaHttpHeaderEntry, usize), Box<NativeHttpError>> {
    if headers.is_empty() {
        return Ok((null_mut(), 0));
    }

    let mut entries = Vec::<NexaHttpHeaderEntry>::with_capacity(headers.len());
    for header in headers {
        let name = CString::new(header.name).map_err(|_| {
            Box::new(NativeHttpError {
                code: "serialization".to_string(),
                message: "Failed to encode response header name.".to_string(),
                status_code: None,
                is_timeout: false,
                uri: None,
                details: None,
            })
        })?;
        let value = CString::new(header.value).map_err(|_| {
            Box::new(NativeHttpError {
                code: "serialization".to_string(),
                message: "Failed to encode response header value.".to_string(),
                status_code: None,
                is_timeout: false,
                uri: None,
                details: None,
            })
        })?;
        let entry = NexaHttpHeaderEntry {
            name_len: name.as_bytes().len(),
            name_ptr: name.into_raw(),
            value_len: value.as_bytes().len(),
            value_ptr: value.into_raw(),
        };
        entries.push(entry);
    }

    let len = entries.len();
    let ptr = entries.as_mut_ptr();
    std::mem::forget(entries);
    Ok((ptr, len))
}

fn build_string_buffer(
    value: Option<String>,
) -> Result<(*mut c_char, usize), Box<NativeHttpError>> {
    let Some(value) = value else {
        return Ok((null_mut(), 0));
    };
    let value = CString::new(value).map_err(|_| {
        Box::new(NativeHttpError {
            code: "serialization".to_string(),
            message: "Failed to encode final URL.".to_string(),
            status_code: None,
            is_timeout: false,
            uri: None,
            details: None,
        })
    })?;
    let length = value.as_bytes().len();
    Ok((value.into_raw(), length))
}

fn free_header_entries_buffer(headers_ptr: *mut NexaHttpHeaderEntry, headers_len: usize) {
    if headers_ptr.is_null() || headers_len == 0 {
        return;
    }

    unsafe {
        let entries = Vec::from_raw_parts(headers_ptr, headers_len, headers_len);
        for entry in entries {
            if !entry.name_ptr.is_null() {
                drop(CString::from_raw(entry.name_ptr.cast_mut()));
            }
            if !entry.value_ptr.is_null() {
                drop(CString::from_raw(entry.value_ptr.cast_mut()));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::response::NativeHttpOwnedBody;
    use bytes::Bytes;
    use std::ffi::CStr;

    #[test]
    fn success_result_preserves_the_response_body_owner_and_frees_all_buffers() {
        let bytes = Bytes::from_static(b"hello");
        let expected_body_ptr = bytes.as_ptr();
        let result = build_binary_success_result(NativeHttpRawResponse {
            status_code: 201,
            headers: vec![NativeHttpHeader {
                name: "content-type".to_string(),
                value: "text/plain".to_string(),
            }],
            body: NativeHttpOwnedBody::from_response_bytes(bytes),
            final_url: Some("https://example.com/final".to_string()),
        });

        assert_eq!(result.is_success, 1);
        assert_eq!(result.status_code, 201);
        assert_eq!(result.body_ptr.cast_const(), expected_body_ptr);
        assert_eq!(result.body_len, 5);
        assert!(!result.body_owner.is_null());
        assert_eq!(result.headers_len, 1);
        assert_eq!(result.final_url_len, 25);
        unsafe {
            assert_eq!(
                CStr::from_ptr((*result.headers_ptr).name_ptr)
                    .to_str()
                    .unwrap(),
                "content-type",
            );
            assert_eq!(
                CStr::from_ptr((*result.headers_ptr).value_ptr)
                    .to_str()
                    .unwrap(),
                "text/plain",
            );
            assert_eq!(
                CStr::from_ptr(result.final_url_ptr).to_str().unwrap(),
                "https://example.com/final",
            );
            free_binary_result(Box::into_raw(Box::new(result)));
        }
    }

    #[test]
    fn error_result_uses_the_same_free_path() {
        let result = build_binary_error_result(NativeHttpError {
            code: "network".to_string(),
            message: "connection refused".to_string(),
            status_code: None,
            is_timeout: false,
            uri: Some("https://example.com".to_string()),
            details: None,
        });

        assert_eq!(result.is_success, 0);
        let error_json = unsafe { CStr::from_ptr(result.error_json) }
            .to_str()
            .unwrap();
        assert!(error_json.contains(r#""code":"network""#));
        unsafe {
            free_binary_result(Box::into_raw(Box::new(result)));
            free_binary_result(std::ptr::null_mut());
        }
    }
}
