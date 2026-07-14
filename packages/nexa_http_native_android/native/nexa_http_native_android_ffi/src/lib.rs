mod proxy_source;

use nexa_http_native_core::runtime::{ManagedProxyState, NexaHttpRuntime};
use once_cell::sync::Lazy;
use proxy_source::ANDROID_PROXY_REFRESH_INTERVAL;

pub use proxy_source::{AndroidProxySource, current_proxy_settings_for_test};

static RUNTIME: Lazy<NexaHttpRuntime<ManagedProxyState<AndroidProxySource>>> = Lazy::new(|| {
    NexaHttpRuntime::new(ManagedProxyState::with_background_refresh(
        AndroidProxySource::new(),
        format!(
            "nexa-http-android-proxy-{}s",
            ANDROID_PROXY_REFRESH_INTERVAL.as_secs()
        ),
    ))
});

nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<AndroidProxySource>,
}
