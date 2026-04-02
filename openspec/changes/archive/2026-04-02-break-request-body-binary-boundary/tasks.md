## 1. Public Request-Body Break

- [x] 1.1 Redefine `RequestBody` so its canonical payload is an owned `Uint8List` and remove compatibility-oriented dual payload state.
- [x] 1.2 Remove deprecated-by-design public helpers and constructors that preserve generic `List<int>` or legacy string-body semantics.
- [x] 1.3 Update public exports, examples, and usage sites to the new binary-first request-body contract.

## 2. Transport Boundary Tightening

- [x] 2.1 Change `NativeHttpRequestDto.bodyBytes` and related request-path helpers to explicit binary buffer types.
- [x] 2.2 Update request mapping and FFI request encoding to consume the canonical owned request-body bytes without transport-specific public accessors.
- [x] 2.3 Remove dead request-default helper abstractions such as `ClientOptions.defaultHeaderEntries`.

## 3. Verification

- [x] 3.1 Update Dart tests to cover the new request-body construction semantics, ownership expectations, and DTO typing.
- [x] 3.2 Run Dart request-path and API-surface tests after the breaking migration.
- [x] 3.3 Run Rust request-path tests to confirm native request execution remains unchanged.
