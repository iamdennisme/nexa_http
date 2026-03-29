use crate::api::request::NativeHttpClientConfig;
use reqwest::Client;

#[derive(Clone)]
pub(crate) struct ClientEntry {
    pub(crate) client: Client,
    pub(crate) config: NativeHttpClientConfig,
    pub(crate) platform_features_signature: String,
    pub(crate) proxy_generation: u64,
}

impl ClientEntry {
    pub(crate) fn new(
        client: Client,
        config: NativeHttpClientConfig,
        platform_features_signature: String,
        proxy_generation: u64,
    ) -> Self {
        Self {
            client,
            config,
            platform_features_signature,
            proxy_generation,
        }
    }
}
