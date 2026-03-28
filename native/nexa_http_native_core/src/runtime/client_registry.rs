use crate::api::request::NativeHttpClientConfig;
use reqwest::Client;

#[derive(Clone)]
pub(crate) struct ClientEntry {
    pub(crate) client: Client,
    pub(crate) config: NativeHttpClientConfig,
    pub(crate) platform_features_signature: String,
    pub(crate) needs_refresh: bool,
}

impl ClientEntry {
    pub(crate) fn new(
        client: Client,
        config: NativeHttpClientConfig,
        platform_features_signature: String,
    ) -> Self {
        Self {
            client,
            config,
            platform_features_signature,
            needs_refresh: false,
        }
    }
}
