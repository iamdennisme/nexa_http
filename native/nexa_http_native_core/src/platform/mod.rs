mod capabilities;
mod proxy;

pub use capabilities::PlatformRuntimeState;
pub use capabilities::PlatformRuntimeView;
pub use proxy::{
    PlatformFeatures, ProxySettings, apply_proxy_strategy, merge_env_fallback,
};
