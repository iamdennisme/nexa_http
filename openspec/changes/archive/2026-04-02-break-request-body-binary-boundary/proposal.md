## Why

The Flutter-to-Rust request path no longer has major FFI overhead, but the public request-body API still carries transport leakage and compatibility-shaped abstractions that are no longer buying us anything.

Today:

- `RequestBody` exposes both public read semantics and an internal FFI handoff accessor.
- `RequestBody.bytes(...)` still accepts a generic `List<int>` even though the bridge is built around owned binary buffers.
- `NativeHttpRequestDto.bodyBytes` remains typed as `List<int>?`, which weakens the transport boundary.
- `ClientOptions.defaultHeaderEntries` is leftover cache machinery from the old request-default merging path and is no longer part of the active design.

This keeps the Dart API looser than the transport contract, leaves dead abstractions in place, and makes the request path harder to reason about than it needs to be.

## What Changes

- Break the public `RequestBody` API so the canonical request-body representation is an owned binary buffer instead of a generic `List<int>`.
- Remove compatibility-shaped accessors and helpers that expose transport internals through `RequestBody`.
- Tighten request transport DTOs and FFI request encoding to use explicit binary buffer semantics end-to-end.
- Delete dead request-default helper abstractions that are no longer used after the previous FFI-overhead cleanup.

## Capabilities

### New Capabilities
- `request-body-binary-boundary`: Make the request-body API and Flutter-to-Rust transport boundary binary-first with no compatibility layer.

### Modified Capabilities
- None.

## Impact

- Affected code: `packages/nexa_http` public request-body API, request mapping, FFI request encoding, examples, and tests.
- Affected APIs: public `RequestBody` construction and any internal code that still accepts generic request byte lists.
- Affected systems: Dart-to-native request-body ownership semantics, request DTO typing, and API clarity for upload paths.
