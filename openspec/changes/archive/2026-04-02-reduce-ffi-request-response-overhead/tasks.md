## 1. Bridge Metadata Fidelity

- [x] 1.1 Replace JSON-based native client creation with structured FFI config args and regenerate Dart bindings.
- [x] 1.2 Change Rust request-header handling to preserve ordered repeated entries and add regression tests for repeated header execution.
- [x] 1.3 Stop returning unchanged final URLs from native success results and update Dart response-mapping coverage for redirect and no-redirect cases.

## 2. Body Ownership Transfer

- [x] 2.1 Add native-owned request-body allocation/adoption so dispatch removes the extra Rust-side request-body copy.
- [x] 2.2 Rework native response-body ownership so reqwest bytes are returned to Dart without re-boxing into a second byte buffer.
- [x] 2.3 Add focused Dart and Rust ownership tests that verify request/response buffers are freed exactly once.

## 3. Native Request Cancellation

- [x] 3.1 Add a native cancel-request ABI plus runtime inflight-request tracking and abort handling.
- [x] 3.2 Thread active request cancellation through the Dart data source, transport session, and `RealCall.cancel()`.
- [x] 3.3 Add race tests for cancel-before-completion, cancel-after-completion, and late native callback disposal.

## 4. Verification

- [x] 4.1 Re-run Dart, Flutter, and Rust regression suites that cover headers, body ownership, and cancellation behavior.
- [x] 4.2 Re-run the Windows benchmark/demo flow and capture post-change throughput and latency deltas against the current baseline.
