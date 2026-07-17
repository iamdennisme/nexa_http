# Decompose Rust executor - Design

## Target Architecture

```text
platform FFI macro
  -> NexaHttpRuntime facade (runtime/executor.rs)
       -> ffi_types        stable C ABI layouts (re-exported by api::ffi)
       -> ffi_decode       raw pointers -> NativeHttp* models
       -> ClientRegistry   client lifecycle + proxy refresh
       -> InflightRequests cancel/callback linearization
       -> request_execution reqwest request -> NativeHttpRawResponse
       -> ffi_result       NativeHttpRawResponse/Error -> owned FFI result
```

Only `NexaHttpRuntime` is re-exported from `runtime`. All new helpers are crate-internal.

### `api/ffi_types.rs`

Owns the C ABI-visible layouts and callback alias formerly declared directly in `api/ffi.rs`. `api::ffi` publicly re-exports the same names, preserving every existing Rust path while allowing decode/result modules to depend on a leaf type module. This avoids an `ffi <-> ffi_result` dependency cycle when the test-result free entry calls the shared result owner.

## Module Boundaries

### `api/ffi_decode.rs`

Owns:

```rust
pub(crate) fn read_client_config(*const NexaHttpClientConfigArgs)
    -> Result<NativeHttpClientConfig, NativeError>;
pub(crate) fn read_request(*const NexaHttpRequestArgs)
    -> Result<NativeHttpRequest, NativeError>;
```

Private helpers decode header arrays and pointer/length strings. This module is the only place that interprets `body_owned`: owned input adopts `Vec::from_raw_parts`; borrowed input copies.

### `api/ffi_result.rs`

Owns:

```rust
pub(crate) fn build_binary_success_result(NativeHttpRawResponse)
    -> NexaHttpBinaryResult;
pub(crate) fn build_binary_error_result(NativeHttpError)
    -> NexaHttpBinaryResult;
pub(crate) unsafe fn free_binary_result(*mut NexaHttpBinaryResult);
```

Header CStrings, final URL, error JSON and response body owner are allocated/freed here. `api/ffi.rs` test helper and `NexaHttpRuntime::binary_result_free` both call this one free implementation.

### `runtime/client_registry.rs`

`ClientRegistry` contains the `Mutex<HashMap<u64, ClientEntry>>` and `AtomicU64`. It owns client creation, removal/count and `resolve_for_request` including generation/signature optimistic retry. `build_client` stays private to the module because it is part of registry entry construction/rebuild.

The registry receives `&P: PlatformRuntimeState`; it does not own `P` and does not decide refresh policy.

### `runtime/inflight.rs`

`InflightRequests` contains the mutex/state map. Its API is command-shaped:

- register pending key
- install abort handle, returning whether the spawned task must be aborted
- cancel, performing state transition and abort outside the lock
- commit callback
- guard cleanup on task exit

The state enum is private to this module. Executor cannot branch on individual variants.

### `runtime/request_execution.rs`

Owns one async boundary:

```rust
pub(crate) async fn execute_with_client(
    client: &reqwest::Client,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError>;
```

Method/header validation, per-request timeout/body, response headers/body/final URL and reqwest cause-chain mapping stay together.

### `runtime/executor.rs`

`NexaHttpRuntimeInner` contains capabilities, `ClientRegistry`, `Arc<InflightRequests>`, Tokio runtime and semaphore. The facade preserves existing method signatures and bootstrap stages. It only sequences:

1. decode input
2. construct/resolve client
3. register/spawn/cancel/commit
4. execute request under permit
5. encode/callback/free through owning modules

Tests that exercise the public runtime stay in `runtime/executor/tests.rs`; responsibility-local tests move with their modules.

## Dependency Direction

```text
executor -> api::{ffi_decode, ffi_result}
executor -> runtime::{client_registry, inflight, request_execution}
client_registry -> api::{error, request} + platform
request_execution -> api::{error, request, response}
inflight -> tokio/std only
ffi -> api::{ffi_types, ffi_result}
ffi_decode -> api::{error, ffi_types, request}
ffi_result -> api::{error, ffi_types, response}
ffi_types -> api::response
```

No child module imports `runtime::executor`. `api/ffi.rs` calls `api::ffi_result` directly for test-result free, removing the prior API-to-runtime back edge; `ffi_result` depends on `ffi_types`, never back on `ffi`.

## Compatibility

- No public Rust/C/Dart signature changes.
- No serialized payload or ownership shape changes.
- Existing `ClientEntry` field values and refresh loop are moved byte-for-byte before cleanup.
- Existing callback linearization state transitions are moved byte-for-byte behind methods before cleanup.
- Request and result helpers are initially moved mechanically; naming/visibility cleanup happens only after tests are green.

## Tests

- `runtime_module_boundaries.rs` reads source modules and asserts ownership markers/forbidden definitions.
- Decode tests cover repeated headers and owned-body adoption.
- Inflight tests cover pending cancel, active abort, unknown cancel and commit winner.
- Request execution test covers reqwest source chain.
- Existing runtime tests cover proxy refresh concurrency and callback delivery.
- Existing integration tests cover ABI, runtime smoke, managed proxy state and all platform crates.

## Rollback

Each module extraction is independently revertible while tests remain green. If visibility pressure creates a cycle, stop and adjust the owner; do not add a forwarding wrapper or make the module public as a shortcut. Final rollback is an overall task revert.
