## 1. Request Metadata Boundary Cleanup

- [x] 1.1 Update Dart request mapping so request DTOs stop embedding client-level default headers and fallback timeout values.
- [x] 1.2 Adjust native request execution coverage to verify client lease defaults still apply while request-specific headers and timeout overrides continue to win.
- [x] 1.3 Regenerate bindings only if the request ABI needs to change; otherwise confirm the existing request contract remains sufficient.

## 2. Lower-Copy Request Body Handoff

- [x] 2.1 Introduce an internal owned-bytes request-body path that can avoid the extra Dart-side defensive materialization before native transfer.
- [x] 2.2 Route FFI request encoding through that owned-bytes path while preserving the existing native-owned transfer and Rust adoption flow.
- [x] 2.3 Add focused tests for request-body ownership, byte preservation, and single-free behavior on the new handoff path.

## 3. Verification

- [x] 3.1 Run Dart tests covering request mapping, request-body encoding, transport-session behavior, and API compatibility.
- [x] 3.2 Run Rust tests covering request execution semantics and body adoption behavior.
- [x] 3.3 Compare the updated request path against the pre-change behavior to confirm the bridge no longer repeats lease-level defaults per request.
