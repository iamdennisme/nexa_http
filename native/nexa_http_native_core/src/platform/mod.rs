mod capabilities;
mod proxy;
mod source;

pub use capabilities::PlatformRuntimeState;
pub use capabilities::PlatformRuntimeView;
pub use proxy::{PlatformFeatures, ProxySettings, apply_proxy_strategy, merge_env_fallback};
pub use source::{ProxyConfigSource, RefreshMode};
