mod capabilities;
mod proxy;

pub use capabilities::PlatformCapabilities;
pub use proxy::{
    PlatformFeatures, ProxySettings, apply_proxy_strategy, merge_env_fallback,
};
