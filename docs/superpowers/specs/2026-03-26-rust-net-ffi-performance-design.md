# rust_net FFI Performance Design

**Goal:** Replace the current `rinf + JSON + base64` hot path with a direct FFI transport that keeps request and response bodies in raw bytes and removes per-request native thread spawning.

## Scope

- Remove `rinf` from the Flutter <-> Rust execution path.
- Move request and response bodies to raw bytes instead of base64.
- Execute requests on a shared Tokio multi-thread runtime with bounded inflight concurrency.
- Keep `RustNetClient` and `RustNetDioAdapter` call sites stable.
- Add regression tests, a benchmark harness, and an example demo for `dio` vs `rust_net`.

## Design

### Dart side

- `FfiRustNetNativeDataSource` will stop using `RustNetRinfRuntime`.
- Requests will be sent through a new async FFI entrypoint:
  - request metadata as JSON
  - request body as raw bytes
  - completion via `NativeCallable.listener`
- Responses will be decoded from `RustNetBinaryResult` directly:
  - headers and errors remain lightweight JSON/text fields
  - body stays as raw bytes

### Rust side

- Remove `rinf` usage and its signal endpoint.
- Replace `reqwest::blocking::Client` with async `reqwest::Client`.
- Add a shared Tokio runtime and a shared semaphore to bound inflight work.
- Keep client reuse and proxy snapshot rebuild behavior.
- Return results through an async callback ABI that hands ownership of `RustNetBinaryResult` back to Dart for freeing.

### Validation

- Add failing tests first for raw request body transport and direct binary result decoding.
- Run Dart unit tests and Rust tests after implementation.
- Add a local benchmark script plus example app demo to compare `rust_net` with direct `dio`.
