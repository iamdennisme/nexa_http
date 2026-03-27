use std::collections::HashMap;

#[derive(Debug, Clone)]
pub(crate) struct NativeHttpRawResponse {
    pub(crate) status_code: u16,
    pub(crate) headers: HashMap<String, Vec<String>>,
    pub(crate) body: Vec<u8>,
    pub(crate) final_url: Option<String>,
}
