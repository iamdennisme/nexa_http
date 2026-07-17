const EXECUTOR: &str = include_str!("../src/runtime/executor.rs");
const CLIENT_REGISTRY: &str = include_str!("../src/runtime/client_registry.rs");
const INFLIGHT: &str = include_str!("../src/runtime/inflight.rs");
const REQUEST_EXECUTION: &str = include_str!("../src/runtime/request_execution.rs");
const FFI: &str = include_str!("../src/api/ffi.rs");
const FFI_DECODE: &str = include_str!("../src/api/ffi_decode.rs");
const FFI_RESULT: &str = include_str!("../src/api/ffi_result.rs");
const FFI_TYPES: &str = include_str!("../src/api/ffi_types.rs");

#[test]
fn runtime_responsibilities_have_single_source_owners() {
    for forbidden in [
        "enum InflightRequestState",
        "fn read_client_config(",
        "fn read_request(",
        "fn build_binary_success_result(",
        "fn build_binary_error_result(",
        "fn map_reqwest_error(",
        "Mutex<HashMap<u64, ClientEntry>>",
        "reqwest::",
        "CString",
        "from_raw_parts",
    ] {
        assert!(
            !EXECUTOR.contains(forbidden),
            "executor must not own {forbidden}"
        );
    }

    assert!(CLIENT_REGISTRY.contains("struct ClientRegistry"));
    assert!(INFLIGHT.contains("struct InflightRequests"));
    assert!(REQUEST_EXECUTION.contains("execute_with_client"));
    assert!(FFI_DECODE.contains("read_client_config"));
    assert!(FFI_DECODE.contains("read_request"));
    assert!(FFI_RESULT.contains("build_binary_success_result"));
    assert!(FFI_RESULT.contains("free_binary_result"));
    assert!(FFI_TYPES.contains("pub struct NexaHttpBinaryResult"));
    assert!(FFI.contains("pub use crate::api::ffi_types"));
}

#[test]
fn extracted_modules_form_an_acyclic_dependency_graph() {
    for (name, source) in [
        ("client_registry", CLIENT_REGISTRY),
        ("inflight", INFLIGHT),
        ("request_execution", REQUEST_EXECUTION),
        ("ffi_decode", FFI_DECODE),
        ("ffi_result", FFI_RESULT),
    ] {
        assert!(
            !source.contains("runtime::executor"),
            "{name} must not depend on the runtime facade"
        );
    }

    for (name, source) in [("ffi_decode", FFI_DECODE), ("ffi_result", FFI_RESULT)] {
        assert!(
            !source.contains("crate::runtime"),
            "{name} must not depend on runtime modules"
        );
    }
    assert!(
        !FFI_RESULT.contains("crate::api::ffi::"),
        "ffi_result must depend on the leaf ffi_types module, not ffi"
    );

    for forbidden in ["crate::api", "crate::platform", "reqwest"] {
        assert!(
            !INFLIGHT.contains(forbidden),
            "inflight must not depend on {forbidden}"
        );
    }
    for forbidden in ["client_registry", "inflight", "api::ffi"] {
        assert!(
            !REQUEST_EXECUTION.contains(forbidden),
            "request_execution must not depend on {forbidden}"
        );
    }
}
