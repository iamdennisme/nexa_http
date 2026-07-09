# Deepen native transport module - Implementation Plan

## Checklist

- [x] Review `prd.md`, `design.md`, and this plan before starting.
- [x] Run `python3 ./.trellis/scripts/task.py start .trellis/tasks/07-07-deepen-native-transport-module` only after user approval.
- [x] Load `trellis-before-dev` before editing product code.
- [x] Read shared specs required for this task:
  - `.trellis/spec/guides/index.md`
  - `.trellis/spec/guides/tdd-development-policy.md`
  - `.trellis/spec/guides/project-layering-contract.md`
  - `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
  - `.trellis/spec/guides/code-reuse-thinking-guide.md`
  - `.trellis/spec/guides/cross-layer-thinking-guide.md`
- [x] RED: add one native transport contract test for the deepened internal interface.
- [x] GREEN: introduce the minimum internal `native transport` module/interface implementation.
- [x] REFACTOR: move production mapper/config/response wiring and lease lifecycle behind the module interface.
- [x] Run focused tests after each GREEN/refactor step.
- [x] Update or remove tests that couple to the old shallow constructor shape, preserving behavior assertions.
- [x] Confirm public API exports are unchanged.
- [x] Run final validation commands.
- [x] Decide whether any learned convention belongs in `.trellis/spec/`; update spec only if there is a durable new rule.
- [ ] Commit task changes after validation.

## TDD Evidence

- RED: `cd packages/nexa_http && fvm dart test test/nexa_http_transport_session_test.dart` failed because `lib/src/internal/transport/nexa_http_native_transport.dart` and `NexaHttpNativeTransport` did not exist.
- GREEN: added `NexaHttpNativeTransport` and moved mapper/config/response wiring behind it; `cd packages/nexa_http && fvm dart test test/nexa_http_transport_session_test.dart` passed.
- REFACTOR: renamed the contract test to `nexa_http_native_transport_test.dart`, wired `NexaHttpClient` to the new transport, removed `NexaHttpTransportSession`, and moved `NexaHttpResponseMapper` into `src/internal/transport`.

## Validation Results

- [x] `cd packages/nexa_http && fvm dart test test/nexa_http_native_transport_test.dart`
- [x] `cd packages/nexa_http && fvm dart test test/call_api_test.dart`
- [x] `cd packages/nexa_http && fvm dart test test/ffi_nexa_http_native_data_source_test.dart`
- [x] `cd packages/nexa_http && fvm dart test test/nexa_http_api_export_test.dart`
- [x] `cd packages/nexa_http && fvm dart test test/nexa_http_client_test.dart`
- [x] `cd packages/nexa_http && fvm dart test test`
- [x] `cd packages/nexa_http && fvm dart analyze`
- [x] `rg -n "nexa_http_transport_session|NexaHttpTransportSession|client/nexa_http_response_mapper|src/client/nexa_http_response_mapper" .` returned no matches.

No durable new `.trellis/spec/` rule was needed. The command-shape correction for package tests is recorded in this task's validation commands.

## Validation Commands

Focused Dart SDK tests:

```bash
cd packages/nexa_http
fvm dart test test/call_api_test.dart
fvm dart test test/nexa_http_native_transport_test.dart
fvm dart test test/ffi_nexa_http_native_data_source_test.dart
fvm dart test test/nexa_http_api_export_test.dart
```

Full affected package test pass:

```bash
cd packages/nexa_http
fvm dart test test
```

Repository guard if any package metadata, carrier, artifact, or consumer verification path changes unexpectedly:

```bash
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
```

These repository guard commands should not be necessary for the intended scope because carrier/native artifact files are out of scope.

## Risky Files

- `packages/nexa_http/lib/src/client/real_call.dart`
- `packages/nexa_http/lib/src/client/nexa_http_transport_session.dart`
- `packages/nexa_http/lib/src/nexa_http_client.dart`
- `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- `packages/nexa_http/test/call_api_test.dart`
- `packages/nexa_http/test/nexa_http_native_transport_test.dart`
- Any new file under `packages/nexa_http/lib/src/internal/transport/`

## Rollback Points

- After RED test: if the intended interface is awkward, revise design before implementation.
- After first GREEN: if the new module is only a wrapper, continue refactor before declaring completion.
- Before touching FFI data source internals: confirm an existing or new failing test requires it.
- Before touching any carrier/native artifact file: stop and revise planning, because that violates current scope.

## Review Gate

Planning is ready for user review when:

- `prd.md` has concrete requirements and acceptance criteria.
- `design.md` describes boundaries, contracts, data flow, and tradeoffs.
- `implement.md` has ordered TDD and validation steps.

Do not start implementation until the user explicitly approves proceeding from planning to implementation.
