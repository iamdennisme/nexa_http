use super::ProxySettings;
use std::time::Duration;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RefreshMode {
    Static,
    Polling { interval: Duration },
}

pub trait ProxyConfigSource: Send + Sync + 'static {
    fn load_current(&self) -> ProxySettings;
    fn refresh_mode(&self) -> RefreshMode;
}
