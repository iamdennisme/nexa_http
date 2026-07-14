mod proxy_source;

use nexa_http_native_core::runtime::{ManagedProxyState, NexaHttpRuntime};
use once_cell::sync::Lazy;

pub use proxy_source::{MacosProxySource, current_proxy_settings_for_test};

static RUNTIME: Lazy<NexaHttpRuntime<ManagedProxyState<MacosProxySource>>> =
    Lazy::new(|| NexaHttpRuntime::new(ManagedProxyState::new(MacosProxySource::new())));

nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<MacosProxySource>,
}
