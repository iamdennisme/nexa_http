use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct NativeHttpClientConfig {
    pub(crate) default_headers: HashMap<String, String>,
    pub(crate) timeout_ms: Option<u64>,
    pub(crate) user_agent: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct NativeHttpRequestMetadata {
    pub(crate) method: String,
    pub(crate) url: String,
    pub(crate) headers: HashMap<String, String>,
    pub(crate) timeout_ms: Option<u64>,
}

#[derive(Debug, Clone)]
pub(crate) struct NativeHttpRequest {
    pub(crate) method: String,
    pub(crate) url: String,
    pub(crate) headers: HashMap<String, String>,
    pub(crate) body: Vec<u8>,
    pub(crate) timeout_ms: Option<u64>,
}
