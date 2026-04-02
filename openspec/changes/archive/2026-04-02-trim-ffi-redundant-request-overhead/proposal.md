## Why

The Flutter-to-Rust bridge has already removed the largest FFI costs, but the request path still carries avoidable overhead. Default client configuration is encoded into every request even though native client leases already hold the same defaults, and request bodies still take an extra Dart-side copy before they reach the native-owned transfer buffer.

## What Changes

- Stop transporting client-level default headers and fallback timeout values on every request when the native lease already owns the same defaults.
- Keep per-request overrides explicit so request-specific headers and timeout behavior remain unchanged.
- Add a lower-copy request body path for the bridge so large payloads can avoid one extra Dart-side materialization before native transfer.
- Preserve the current public `NexaHttpClient`, `Request`, and `Response` API behavior while tightening internal bridge responsibilities.

## Capabilities

### New Capabilities
- `ffi-request-overhead-trimming`: Remove redundant request metadata transport and support a lower-copy request body handoff path.

### Modified Capabilities
- None.

## Impact

- Affected code: `packages/nexa_http` request mapping and FFI encoding, `native/nexa_http_native_core` request execution, and generated FFI bindings if the request contract changes.
- Affected APIs: internal Flutter-to-Rust request ABI and internal request body ownership helpers.
- Affected systems: hot-path request dispatch cost, large-body upload memory pressure, and the separation of client-level defaults vs request-level overrides.
