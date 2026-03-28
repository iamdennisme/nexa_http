use super::{PlatformFeatures, ProxySettings};

pub trait PlatformCapabilities: Send + Sync + 'static {
    fn proxy_settings(&self) -> ProxySettings;

    fn platform_features(&self) -> PlatformFeatures {
        PlatformFeatures::with_env_fallback(self.proxy_settings())
    }

    fn platform_signature(&self) -> String {
        self.platform_features().signature()
    }
}
