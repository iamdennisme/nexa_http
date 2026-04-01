## Why

The Flutter-to-Rust bridge is now the main remaining hot-path cost center in `nexa_http`. It still loses repeated request headers, performs avoidable request and response body copies, ships unchanged final-URL metadata, and cannot cancel in-flight native work after dispatch.

## What Changes

- Preserve repeated request headers and header order all the way through Rust request execution instead of collapsing them into a map.
- Replace JSON-based native client creation config with a structured FFI contract.
- Reduce request hot-path copying by transferring request body ownership into Rust after one Dart-to-native materialization.
- Reduce response hot-path copying by returning native-owned response body buffers to Dart without re-boxing reqwest bytes.
- Omit final URL transport when the native response URL matches the original request URL.
- Add request-level cancellation so `Call.cancel()` can abort active native work and suppress late successful results.

## Capabilities

### New Capabilities
- `ffi-bridge-metadata-fidelity`: Preserve request metadata semantics and remove avoidable bridge metadata traffic.
- `ffi-body-ownership-transfer`: Reduce request and response body copies through explicit native ownership transfer.
- `native-request-cancellation`: Propagate Dart call cancellation into the native runtime.

### Modified Capabilities

- None.

## Impact

- Affected code: `packages/nexa_http`, generated FFI bindings, `native/nexa_http_native_core`, and platform FFI crates that export the shared ABI.
- Affected APIs: internal native ABI for client creation, request execution, response result ownership, and request cancellation.
- Affected systems: benchmark hot path, request header fidelity, response mapping, and in-flight request lifecycle management.
