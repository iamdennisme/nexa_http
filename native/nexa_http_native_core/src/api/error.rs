use serde::Serialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct NativeHttpError {
    pub code: String,
    pub message: String,
    pub status_code: Option<u16>,
    pub is_timeout: bool,
    pub uri: Option<String>,
    pub details: Option<HashMap<String, String>>,
}

#[derive(Debug)]
pub(crate) struct NativeError {
    pub(crate) code: &'static str,
    pub(crate) message: String,
    pub(crate) status_code: Option<u16>,
    pub(crate) is_timeout: bool,
    pub(crate) uri: Option<String>,
    pub(crate) details: Option<HashMap<String, String>>,
}

impl NativeError {
    pub(crate) fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            status_code: None,
            is_timeout: false,
            uri: None,
            details: None,
        }
    }

    pub(crate) fn with_uri(mut self, uri: impl Into<String>) -> Self {
        self.uri = Some(uri.into());
        self
    }

    pub(crate) fn with_timeout(mut self) -> Self {
        self.is_timeout = true;
        self
    }

    pub(crate) fn with_details(mut self, details: HashMap<String, String>) -> Self {
        self.details = Some(details);
        self
    }

    pub(crate) fn into_http_error(self) -> NativeHttpError {
        NativeHttpError {
            code: self.code.to_string(),
            message: self.message,
            status_code: self.status_code,
            is_timeout: self.is_timeout,
            uri: self.uri,
            details: self.details,
        }
    }
}
