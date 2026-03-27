pub mod api {
    pub mod error;
    pub mod ffi;
    pub mod request;
    pub mod response;
}

pub mod platform;

pub mod runtime {
    pub mod client_registry;
    pub mod executor;
    pub mod tokio_runtime;

    pub use executor::NexaHttpRuntime;
}
