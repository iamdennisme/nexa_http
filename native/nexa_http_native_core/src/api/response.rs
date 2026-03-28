use crate::api::request::NativeHttpHeader;

#[derive(Debug, Clone)]
pub(crate) struct NativeHttpRawResponse {
    pub(crate) status_code: u16,
    pub(crate) headers: Vec<NativeHttpHeader>,
    pub(crate) body: Vec<u8>,
    pub(crate) final_url: Option<String>,
}
