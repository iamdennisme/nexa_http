use crate::api::request::NativeHttpClientConfig;
use reqwest::Client;

#[derive(Clone)]
pub(crate) struct ClientEntry {
    pub(crate) client: Client,
    pub(crate) config: NativeHttpClientConfig,
    pub(crate) platform_features_signature: String,
}
