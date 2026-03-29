use super::{PlatformFeatures, ProxySettings};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PlatformRuntimeView {
    pub proxy_generation: u64,
    pub platform_features: PlatformFeatures,
}

impl PlatformRuntimeView {
    pub fn with_proxy_settings(proxy_generation: u64, proxy: ProxySettings) -> Self {
        Self {
            proxy_generation,
            platform_features: PlatformFeatures::with_env_fallback(proxy),
        }
    }
}

pub trait PlatformRuntimeState: Send + Sync + 'static {
    fn proxy_generation(&self) -> u64;
    fn current_platform_state(&self) -> PlatformRuntimeView;
}
