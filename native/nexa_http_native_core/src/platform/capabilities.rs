use super::ProxySettings;

pub trait PlatformCapabilities: Send + Sync + 'static {
    fn proxy_settings(&self) -> ProxySettings;

    fn platform_signature(&self) -> String {
        self.proxy_settings().signature()
    }
}
