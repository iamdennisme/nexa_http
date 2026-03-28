use std::collections::HashMap;

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
    pub(crate) headers: HashMap<String, String>,
    pub(crate) body: Vec<u8>,
    pub(crate) timeout_ms: Option<u64>,
}
