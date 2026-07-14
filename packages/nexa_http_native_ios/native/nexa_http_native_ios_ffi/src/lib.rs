mod proxy_source;

use nexa_http_native_core::runtime::{ManagedProxyState, NexaHttpRuntime};
use once_cell::sync::Lazy;

pub use proxy_source::{IosProxySource, current_proxy_settings_for_test};

static RUNTIME: Lazy<NexaHttpRuntime<ManagedProxyState<IosProxySource>>> =
    Lazy::new(|| NexaHttpRuntime::new(ManagedProxyState::new(IosProxySource::new())));

nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<IosProxySource>,
}
