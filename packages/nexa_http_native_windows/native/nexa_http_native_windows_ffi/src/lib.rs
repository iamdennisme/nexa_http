mod proxy_source;

use nexa_http_native_core::runtime::{ManagedProxyState, NexaHttpRuntime};
use once_cell::sync::Lazy;

pub use proxy_source::{WindowsProxySource, current_proxy_settings_for_test};

static RUNTIME: Lazy<NexaHttpRuntime<ManagedProxyState<WindowsProxySource>>> =
    Lazy::new(|| NexaHttpRuntime::new(ManagedProxyState::new(WindowsProxySource::new())));

nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<WindowsProxySource>,
}
