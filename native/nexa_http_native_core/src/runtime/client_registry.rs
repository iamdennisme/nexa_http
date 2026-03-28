use crate::api::request::NativeHttpClientConfig;
use reqwest::Client;
use std::time::Instant;

#[derive(Clone)]
pub(crate) struct ClientEntry {
    pub(crate) client: Client,
    pub(crate) config: NativeHttpClientConfig,
    pub(crate) platform_features_signature: String,
    pub(crate) needs_refresh: bool,
    pub(crate) refresh_in_progress: bool,
    pub(crate) next_refresh_probe_at: Instant,
}

impl ClientEntry {
    pub(crate) fn new(
        client: Client,
        config: NativeHttpClientConfig,
        platform_features_signature: String,
        next_refresh_probe_at: Instant,
    ) -> Self {
        Self {
            client,
            config,
            platform_features_signature,
            needs_refresh: false,
            refresh_in_progress: false,
            next_refresh_probe_at,
        }
    }
}
