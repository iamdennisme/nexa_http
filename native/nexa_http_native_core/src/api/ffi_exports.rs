/// Defines the uniform native C ABI around a platform-owned HTTP runtime.
#[macro_export]
macro_rules! export_nexa_http_ffi {
    (
        runtime = $runtime:expr,
        state = $state:ty $(,)?
    ) => {
        fn __nexa_http_runtime() -> &'static $crate::runtime::NexaHttpRuntime<$state> {
            &*$runtime
        }

        #[unsafe(no_mangle)]
        pub extern "C" fn nexa_http_client_create(
            config_args: *const $crate::api::ffi::NexaHttpClientConfigArgs,
        ) -> u64 {
            __nexa_http_runtime().create_client(config_args)
        }

        #[unsafe(no_mangle)]
        pub extern "C" fn nexa_http_take_last_error_json() -> *mut ::std::ffi::c_char {
            $crate::api::ffi::take_last_error_json()
        }

        #[unsafe(no_mangle)]
        pub unsafe extern "C" fn nexa_http_string_free(value: *mut ::std::ffi::c_char) {
            unsafe { $crate::api::ffi::string_free(value) };
        }

        #[unsafe(no_mangle)]
        pub extern "C" fn nexa_http_request_body_alloc(body_len: usize) -> *mut u8 {
            $crate::runtime::NexaHttpRuntime::<$state>::request_body_alloc(body_len)
        }

        #[unsafe(no_mangle)]
        pub unsafe extern "C" fn nexa_http_request_body_free(body_ptr: *mut u8, body_len: usize) {
            unsafe {
                $crate::runtime::NexaHttpRuntime::<$state>::request_body_free(body_ptr, body_len);
            }
        }

        #[unsafe(no_mangle)]
        pub extern "C" fn nexa_http_client_execute_async(
            client_id: u64,
            request_id: u64,
            request_args: *const $crate::api::ffi::NexaHttpRequestArgs,
            callback: $crate::api::ffi::NexaHttpExecuteCallback,
        ) -> u8 {
            __nexa_http_runtime().execute_async(client_id, request_id, request_args, callback)
        }

        #[unsafe(no_mangle)]
        pub extern "C" fn nexa_http_client_cancel_request(client_id: u64, request_id: u64) -> u8 {
            __nexa_http_runtime().cancel_request(client_id, request_id)
        }

        #[unsafe(no_mangle)]
        pub extern "C" fn nexa_http_client_close(client_id: u64) {
            __nexa_http_runtime().close_client(client_id);
        }

        #[unsafe(no_mangle)]
        pub unsafe extern "C" fn nexa_http_binary_result_free(
            value: *mut $crate::api::ffi::NexaHttpBinaryResult,
        ) {
            unsafe {
                $crate::runtime::NexaHttpRuntime::<$state>::binary_result_free(value);
            }
        }

        const _: extern "C" fn(*const $crate::api::ffi::NexaHttpClientConfigArgs) -> u64 =
            nexa_http_client_create;
        const _: extern "C" fn() -> *mut ::std::ffi::c_char = nexa_http_take_last_error_json;
        const _: unsafe extern "C" fn(*mut ::std::ffi::c_char) = nexa_http_string_free;
        const _: extern "C" fn(usize) -> *mut u8 = nexa_http_request_body_alloc;
        const _: unsafe extern "C" fn(*mut u8, usize) = nexa_http_request_body_free;
        const _: extern "C" fn(
            u64,
            u64,
            *const $crate::api::ffi::NexaHttpRequestArgs,
            $crate::api::ffi::NexaHttpExecuteCallback,
        ) -> u8 = nexa_http_client_execute_async;
        const _: extern "C" fn(u64, u64) -> u8 = nexa_http_client_cancel_request;
        const _: extern "C" fn(u64) = nexa_http_client_close;
        const _: unsafe extern "C" fn(*mut $crate::api::ffi::NexaHttpBinaryResult) =
            nexa_http_binary_result_free;
    };
}
