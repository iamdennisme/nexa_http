# Deepen native transport module

## Goal

Deepen the `native transport` module in `packages/nexa_http` so request execution lifecycle rules have better locality behind a narrower internal interface, while preserving the public Dart SDK contract and the unified async FFI transport contract.

This task continues the architecture review top recommendation from `/var/folders/cd/sw2110553dq651kvkmh937jw0000gn/T/architecture-review-20260707-005309.html`: "Deepen the native transport module".

## Background

Confirmed repository facts:

- `CONTEXT.md` defines `native transport` as the Dart path that maps `Request` into native DTOs, calls the `uniform C ABI`, and maps native responses/errors back to public SDK objects.
- ADR-0001 requires runtime lifecycle, FFI ownership, platform registration, and native integration details to stay out of `package:nexa_http/nexa_http.dart`.
- ADR-0003 requires all platforms to keep one unified async FFI transport pipeline using the same `nexa_http_*` C ABI.
- Current request lifecycle logic is split across several shallow modules:
  - `packages/nexa_http/lib/src/client/real_call.dart:37` owns execute/cancel state and native cancellation forwarding.
  - `packages/nexa_http/lib/src/client/nexa_http_transport_session.dart:43` owns lease creation, request mapping, response mapping, and close/dispose lifecycle.
  - `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart:100` owns request id registration, FFI async dispatch, cancel completion, callback draining, and result ownership.
- Existing tests already cover public call semantics and lower-level FFI behavior:
  - `packages/nexa_http/test/call_api_test.dart:40`
  - `packages/nexa_http/test/nexa_http_native_transport_test.dart`
  - `packages/nexa_http/test/ffi_nexa_http_native_data_source_test.dart:341`

## Requirements

- R1: Preserve the public Dart SDK surface. Host runtime code must still import only `package:nexa_http/nexa_http.dart`; no new host-visible native lifecycle API is allowed.
- R2: Preserve the unified async FFI transport. Do not introduce platform-specific Dart request execution paths or change the C ABI in this task.
- R3: Introduce or reshape a stable internal `native transport` module interface that owns lease lifecycle, request mapping, response mapping, and cancellation handoff in one place.
- R4: Keep `RealCall` responsible for public `Call` state (`isExecuted`, `isCanceled`, `clone`) but keep FFI/native execution details behind the `native transport` interface.
- R5: Preserve existing behavior for lease reuse, client close/dispose, dispatch failure, cancellation before execution, in-flight cancellation, late native callback cleanup, and native response body ownership.
- R6: Follow TDD with vertical slices. The first implementation step must add or update one behavior test, observe RED, implement the minimum GREEN change, then refactor.
- R7: Keep scope to `packages/nexa_http` internal transport. Do not include Apple proxy parser or platform FFI export glue in this task.

## Flutter SDK Contract Mapping

- Host dependency declaration: unchanged; consumers still depend on `nexa_http` plus target `nexa_http_native_<platform>` carrier packages.
- Host runtime import: unchanged; runtime code imports `package:nexa_http/nexa_http.dart` only.
- Hidden internals: the new/deepened `native transport` module remains under `packages/nexa_http/lib/src/...`; it is not documented as app-facing API.
- Native lifecycle ownership: unchanged; native library loading and platform carrier registration stay internal.
- Artifact packaging/download: out of scope; no carrier hook, target matrix, release manifest, or native artifact materialization changes.
- Failure reporting: existing `NexaHttpException` behavior must remain stable for canceled calls, dispatch failure, and native bootstrap failure.
- Clean-host acceptance: no new host integration step is allowed. Package tests are sufficient unless implementation unexpectedly touches carrier/package integration files.

## Acceptance Criteria

- [x] AC1: `packages/nexa_http/lib/nexa_http.dart` exports are unchanged, and `packages/nexa_http/test/nexa_http_api_export_test.dart` passes.
- [x] AC2: A native transport contract test exists for the new/deepened internal interface and covers at least one behavior that previously required coordinating multiple shallow modules.
- [x] AC3: `Call` cancellation behavior remains stable: cancel before execute blocks execution, in-flight cancel forwards once, and cancel after completion does not forward.
- [x] AC4: Native lease behavior remains stable: repeated executions reuse one native lease and close/dispose happens once.
- [x] AC5: FFI data source behavior remains stable: async dispatch, dispatch failure, cancellation, late callback cleanup, and native result/body ownership tests pass.
- [x] AC6: No carrier hook, native artifact, target matrix, release consumer, Rust core, or platform FFI crate files are modified unless planning is revised first.
- [x] AC7: TDD evidence is recorded in the final summary: which test was RED first, which commands passed after GREEN/refactor.

## Out Of Scope

- Apple proxy settings parser deepening.
- Platform FFI export glue concentration.
- C ABI changes or regenerated FFI bindings.
- Carrier build hook, artifact packaging, release asset, or clean-host consumer changes.
- Public API additions such as runtime warm-up, shutdown, registration, or transport selection.

## Open Questions

No blocking product questions remain. The user has approved creating the task and continuing this architecture refactor. Repository evidence is sufficient to plan the first implementation slice.
