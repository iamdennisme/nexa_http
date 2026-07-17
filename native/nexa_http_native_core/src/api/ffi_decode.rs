use crate::api::error::NativeError;
use crate::api::ffi_types::{NexaHttpClientConfigArgs, NexaHttpHeaderEntry, NexaHttpRequestArgs};
use crate::api::request::{
    NativeHttpClientConfig, NativeHttpHeader, NativeHttpOwnedRequestBody, NativeHttpRequest,
};
use std::collections::HashMap;
use std::ffi::c_char;
use std::slice::from_raw_parts;

pub(crate) fn read_client_config(
    config_args: *const NexaHttpClientConfigArgs,
) -> Result<NativeHttpClientConfig, NativeError> {
    let config_args = unsafe { config_args.as_ref() }.ok_or_else(|| {
        NativeError::new(
            "invalid_argument",
            "Expected a non-null client config args pointer.",
        )
    })?;

    let default_headers = read_config_headers(
        config_args.default_headers_ptr,
        config_args.default_headers_len,
    )?;
    let user_agent = read_optional_string_parts(
        config_args.user_agent_ptr,
        config_args.user_agent_len,
        "client user agent",
    )?;

    Ok(NativeHttpClientConfig {
        default_headers,
        timeout_ms: if config_args.has_timeout == 0 {
            None
        } else {
            Some(config_args.timeout_ms)
        },
        user_agent,
    })
}

pub(crate) fn read_request(
    request_args: *const NexaHttpRequestArgs,
) -> Result<NativeHttpRequest, NativeError> {
    let request_args = unsafe { request_args.as_ref() }.ok_or_else(|| {
        NativeError::new(
            "invalid_argument",
            "Expected a non-null request args pointer.",
        )
    })?;

    let body = if request_args.body_len == 0 {
        Vec::new()
    } else if request_args.body_ptr.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null body pointer when body_len > 0.",
        ));
    } else if request_args.body_owned != 0 {
        unsafe {
            NativeHttpOwnedRequestBody::into_vec(request_args.body_ptr, request_args.body_len)
        }
    } else {
        unsafe { from_raw_parts(request_args.body_ptr, request_args.body_len) }.to_vec()
    };

    let headers = read_request_headers(request_args.headers_ptr, request_args.headers_len)?;

    Ok(NativeHttpRequest {
        method: read_string_parts(
            request_args.method_ptr,
            request_args.method_len,
            "request method",
        )?,
        url: read_string_parts(request_args.url_ptr, request_args.url_len, "request URL")?,
        headers,
        body,
        timeout_ms: if request_args.has_timeout == 0 {
            None
        } else {
            Some(request_args.timeout_ms)
        },
    })
}

fn read_request_headers(
    headers_ptr: *const NexaHttpHeaderEntry,
    headers_len: usize,
) -> Result<Vec<NativeHttpHeader>, NativeError> {
    if headers_len == 0 {
        return Ok(Vec::new());
    }
    if headers_ptr.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            "Expected a non-null headers pointer when headers_len > 0.",
        ));
    }

    let mut headers = Vec::with_capacity(headers_len);
    for entry in unsafe { from_raw_parts(headers_ptr, headers_len) } {
        let name = read_string_parts(entry.name_ptr, entry.name_len, "request header name")?;
        let value = read_string_parts(entry.value_ptr, entry.value_len, "request header value")?;
        headers.push(NativeHttpHeader { name, value });
    }
    Ok(headers)
}

fn read_config_headers(
    headers_ptr: *const NexaHttpHeaderEntry,
    headers_len: usize,
) -> Result<HashMap<String, String>, NativeError> {
    let mut headers = HashMap::new();
    for entry in read_request_headers(headers_ptr, headers_len)? {
        headers.insert(entry.name, entry.value);
    }
    Ok(headers)
}

fn read_string_parts(
    pointer: *const c_char,
    length: usize,
    field_name: &'static str,
) -> Result<String, NativeError> {
    if length == 0 {
        return Ok(String::new());
    }
    if pointer.is_null() {
        return Err(NativeError::new(
            "invalid_argument",
            format!("Expected a non-null pointer for {field_name}."),
        ));
    }

    let bytes = unsafe { from_raw_parts(pointer.cast::<u8>(), length) };
    let value = std::str::from_utf8(bytes)
        .map_err(|error| NativeError::new("invalid_utf8", error.to_string()))?;
    Ok(value.to_string())
}

fn read_optional_string_parts(
    pointer: *const c_char,
    length: usize,
    field_name: &'static str,
) -> Result<Option<String>, NativeError> {
    if length == 0 {
        return Ok(None);
    }
    Ok(Some(read_string_parts(pointer, length, field_name)?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn request_headers_preserve_repeated_entries_in_order() {
        let header_names = [
            CString::new("accept").unwrap(),
            CString::new("accept").unwrap(),
        ];
        let header_values = [
            CString::new("application/json").unwrap(),
            CString::new("application/problem+json").unwrap(),
        ];
        let headers = [
            NexaHttpHeaderEntry {
                name_ptr: header_names[0].as_ptr(),
                name_len: header_names[0].as_bytes().len(),
                value_ptr: header_values[0].as_ptr(),
                value_len: header_values[0].as_bytes().len(),
            },
            NexaHttpHeaderEntry {
                name_ptr: header_names[1].as_ptr(),
                name_len: header_names[1].as_bytes().len(),
                value_ptr: header_values[1].as_ptr(),
                value_len: header_values[1].as_bytes().len(),
            },
        ];

        let decoded = read_request_headers(headers.as_ptr(), headers.len()).unwrap();

        assert_eq!(decoded.len(), 2);
        assert_eq!(decoded[0].name, "accept");
        assert_eq!(decoded[0].value, "application/json");
        assert_eq!(decoded[1].name, "accept");
        assert_eq!(decoded[1].value, "application/problem+json");
    }

    #[test]
    fn owned_request_body_is_adopted_without_recopying() {
        let method = CString::new("POST").unwrap();
        let url = CString::new("https://example.com/upload").unwrap();
        let body_ptr = NativeHttpOwnedRequestBody::alloc_raw_parts(4);
        unsafe {
            std::slice::from_raw_parts_mut(body_ptr, 4).copy_from_slice(&[1, 2, 3, 4]);
        }
        let args = NexaHttpRequestArgs {
            method_ptr: method.as_ptr(),
            method_len: method.as_bytes().len(),
            url_ptr: url.as_ptr(),
            url_len: url.as_bytes().len(),
            headers_ptr: std::ptr::null(),
            headers_len: 0,
            body_ptr,
            body_len: 4,
            body_owned: 1,
            timeout_ms: 0,
            has_timeout: 0,
        };

        let request = read_request(&args).unwrap();

        assert_eq!(request.body, vec![1, 2, 3, 4]);
        assert_eq!(request.body.as_ptr(), body_ptr.cast_const());
    }

    #[test]
    fn borrowed_request_body_is_copied_before_async_execution() {
        let method = CString::new("POST").unwrap();
        let url = CString::new("https://example.com/upload").unwrap();
        let mut body = vec![1, 2, 3, 4];
        let args = NexaHttpRequestArgs {
            method_ptr: method.as_ptr(),
            method_len: method.as_bytes().len(),
            url_ptr: url.as_ptr(),
            url_len: url.as_bytes().len(),
            headers_ptr: std::ptr::null(),
            headers_len: 0,
            body_ptr: body.as_mut_ptr(),
            body_len: body.len(),
            body_owned: 0,
            timeout_ms: 0,
            has_timeout: 0,
        };

        let request = read_request(&args).unwrap();

        assert_eq!(request.body, vec![1, 2, 3, 4]);
        assert_ne!(request.body.as_ptr(), body.as_ptr());
    }
}
