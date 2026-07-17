mod capabilities;
mod proxy;
mod proxy_normalization;
mod source;

pub use capabilities::PlatformRuntimeState;
pub use capabilities::PlatformRuntimeView;
pub use proxy::{PlatformFeatures, ProxySettings, apply_proxy_strategy, merge_env_fallback};
pub use proxy_normalization::{
    canonicalize_bypass_rules, clean_proxy_value, normalize_proxy_url, split_bypass_rules,
};
pub use source::{ProxyConfigSource, RefreshMode};
