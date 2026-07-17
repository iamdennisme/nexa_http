pub mod api {
    pub mod error;
    pub mod ffi;
    pub(crate) mod ffi_decode;
    mod ffi_exports;
    pub(crate) mod ffi_result;
    pub(crate) mod ffi_types;
    pub mod request;
    pub mod response;
}

pub mod platform;

pub mod runtime {
    mod client_registry;
    pub mod executor;
    mod inflight;
    pub mod managed_proxy_state;
    mod request_execution;
    pub mod tokio_runtime;

    pub use executor::NexaHttpRuntime;
    pub use managed_proxy_state::ManagedProxyState;
}
