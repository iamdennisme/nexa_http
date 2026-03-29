# Unified Async FFI Transport Design

## Context

The project direction is now clear:

- platform differences should live in `native_<platform>`
- `native core` should own the shared HTTP execution logic
- the Flutter/Dart public layer should stay platform-neutral

Today the main exception is Android request execution.
The public Dart bridge still supports two execution models:

- the normal async callback path used by iOS, macOS, and Windows
- an Android-preferred binary execution path that uses `Isolate.run`, DTO JSON round-trips, and a separate runtime contract field

That split creates two problems:

1. Android request execution is no longer aligned with the rest of the transport stack.
2. Public-layer abstractions still carry Android-specific execution concepts that should not exist there.

## Goals

- Use one async FFI execution pipeline for every supported platform.
- Remove Android-specific request execution branching from the public Dart bridge.
- Shrink the public runtime contract so it only covers native library loading.
- Keep platform-specific code limited to proxy state, native library location, packaging, and platform capability access.
- Improve request-path performance by removing Android-only isolate and JSON transport overhead.

## Non-Goals

- Redesign the public `NexaHttpClient` API.
- Change proxy semantics or the new platform-owned proxy runtime state model.
- Introduce zero-copy body transport in this phase.
- Remove reasonable carrier-side packaged/workspace discovery fallback logic in the same change.

## Current Problem

The current Dart bridge exposes Android-specific execution concerns through:

- `nexa_http_runtime_prefers_binary_execution()`
- `binaryExecutionLibraryPath`
- `preferSynchronousExecution`
- a binary executor path that serializes request DTOs to JSON, runs in a background isolate, rehydrates DTOs, then calls `execute_binary`

This means platform-specific behavior is leaking into:

- the public runtime contract
- the shared Dart data source
- performance-critical request execution

That is the wrong boundary.
Platform-specific code should determine how to open and initialize a native runtime, not which request transport pipeline the app uses.

## Design Summary

The transport stack should be reduced to a single shared request pipeline:

1. Dart maps `NexaHttpRequest` into `NativeHttpRequestDto`
2. Dart allocates `NexaHttpRequestArgs`
3. Dart always calls `nexa_http_client_execute_async`
4. `native core` executes the request on its runtime
5. `native core` returns `NexaHttpBinaryResult` through the callback
6. Dart decodes the result and adopts the body buffer through the existing finalizer-based path

Under this design:

- Android no longer has a separate request model
- `native core` continues to own the shared execution engine
- platform runtimes only expose platform state and native library loading

## Desired Layer Boundaries

### Dart Public Layer

`packages/nexa_http` should expose:

- `NexaHttpClient`
- request / response / exception models
- a single async FFI-backed native data source

It should not expose:

- binary execution preferences
- Android-specific execution flags
- any second request pipeline

### Native Core

`native/nexa_http_native_core` should expose:

- `create_client`
- `execute_async`
- `close_client`
- result-free APIs

It should not expose:

- a platform preference symbol for request execution mode
- Android-specific execution semantics

### Platform Native Modules

Each `native_<platform>` module should own:

- proxy snapshot / generation state
- platform system integration
- exported runtime entry points

They should not define platform-specific request transport models.

### Dart Carrier Packages

Each carrier package should own:

- runtime registration
- `DynamicLibrary` loading
- packaged / workspace / explicit-path discovery

The runtime contract should become:

```dart
abstract interface class NexaHttpNativeRuntime {
  DynamicLibrary open();
}
```

No platform should need to provide `binaryExecutionLibraryPath`.

## API Changes

### Remove from Native ABI

Remove:

- `nexa_http_runtime_prefers_binary_execution()`

The native ABI should only expose the actual transport entry points:

- `nexa_http_client_create`
- `nexa_http_client_execute_async`
- `nexa_http_client_close`
- `nexa_http_binary_result_free`

### Remove from Dart Runtime Contract

Remove:

- `binaryExecutionLibraryPath`

`NexaHttpNativeRuntime` should only provide `open()`.

### Remove from Dart Data Source

Remove:

- `preferSynchronousExecution`
- `binaryExecutor`
- `binaryExecutionLibraryPath`
- `_executeBinaryInBackgroundIsolate`
- `_BinaryExecuteRequest`
- synchronous-only binary decode helpers that only exist for the Android path

Keep:

- the async callback-based decode path
- finalizer-based response body adoption

## Data Flow After Unification

### Client Create

1. Dart loads the platform runtime library through `open()`
2. Dart creates bindings
3. Dart passes the config JSON to `nexa_http_client_create`
4. `native core` creates and stores the shared reqwest client

### Request Execute

1. Dart builds `NativeHttpRequestArgs`
2. Dart calls `nexa_http_client_execute_async`
3. `native core` resolves the client and executes the request
4. `native core` invokes the callback with `NexaHttpBinaryResult`
5. Dart decodes headers / final URL and adopts the body buffer

No platform-specific transport branching occurs here.

## Performance Impact

This change should improve Android execution by removing:

- isolate scheduling overhead
- request DTO `toJson()/fromJson()` round-trips
- isolate message copying of request data
- binary-execution-only decode helpers

This does not yet remove all FFI body copies, but it removes the Android-only extra copies caused by the second transport path.

## Remaining Platform-Specific Logic

These differences are valid and should remain:

- Android proxy discovery via `getprop`
- Apple proxy discovery via SystemConfiguration
- Windows proxy discovery via registry
- platform-specific native library lookup and bundle layout

These are platform capabilities, not request transport differences.

## Migration Strategy

### Phase 1

- remove the Android binary execution split
- unify Dart on the async callback transport path
- shrink `NexaHttpNativeRuntime`
- remove the binary preference symbol from native modules

### Phase 2

- clean up tests, docs, and generated bindings
- remove dead code introduced only for the binary path

### Phase 3

- optionally follow up with deeper performance work:
  - fewer body copies
  - finer-grained client registry locking

## Testing Strategy

### Dart / Flutter

Add or update tests that verify:

- the shared data source always dispatches through `execute_async`
- no binary executor contract is required
- all platform runtime registrations still allow client creation and requests

### Native ABI

Verify:

- generated bindings no longer reference `nexa_http_runtime_prefers_binary_execution`
- platform crates still export the shared transport entry points

### Workspace Validation

Run:

- `cargo test --workspace`
- `fvm dart test` in `packages/nexa_http`
- `fvm flutter test` in `packages/nexa_http/example`
- `fvm dart run scripts/workspace_tools.dart analyze`

## Expected Outcome

After this change:

- every platform uses the same request execution model
- Android stops being a transport outlier
- the public Dart layer no longer carries platform execution concepts
- platform-specific logic is reduced to true platform capabilities and packaging concerns
