# Deepen Dart native transport module - Implementation Plan

## Preconditions

- [x] User authorized automatic completion, verification, commit and archive of all outstanding tasks.
- [x] Prior lifecycle design, current source graph, package specs, ADRs and session history reviewed.
- [x] Activate only after `prd.md`, `design.md` and this plan pass convergence review.
- [x] Load `trellis-before-dev` before product edits.

## Ordered Checklist

- [x] Record `packages/nexa_http` format/analyze/test baseline.
- [x] RED: add `test/native_transport_dependency_test.dart`; confirm legacy directories/import topology fail for the intended reason.
- [x] Move all 19 transport-only files to flat `lib/src/internal/native_transport/` in one clean cutover.
- [x] Update internal relative imports and generated `part` relationships without changing symbols or control flow.
- [x] Move production default factory/testing override selection behind `NexaHttpNativeTransport`; reduce `NexaHttpClient` to the facade import.
- [x] Update 11 package test import sets and keep behavior assertions unchanged.
- [x] GREEN: run dependency contract and focused facade/factory/cancellation/ownership tests.
- [x] Run build_runner and verify generated files are fresh at the new path with no old output.
- [x] Update current package specs and ADR source references; do not touch archived tasks.
- [x] Search production/spec/current ADR for old directories, forwarders and unauthorized feature imports.
- [x] Run final package format/analyze/full tests, public surface tests and Apple clean-host integration.
- [x] Update acceptance and TDD evidence before commit/archive.

## Validation Commands

```bash
cd packages/nexa_http
fvm dart format --output=none --set-exit-if-changed lib test
fvm dart analyze
fvm dart test test/native_transport_dependency_test.dart
fvm dart test test/nexa_http_native_transport_test.dart \
  test/nexa_http_native_data_source_factory_test.dart \
  test/ffi_nexa_http_native_data_source_test.dart \
  test/ffi_nexa_http_pending_request_registry_test.dart \
  test/call_api_test.dart
fvm dart test test/ffi_nexa_http_request_encoder_test.dart \
  test/ffi_nexa_http_response_decoder_test.dart \
  test/nexa_http_response_mapper_test.dart \
  test/request_body_test.dart \
  test/response_body_test.dart
fvm dart test test/nexa_http_api_export_test.dart test/public_api_negative_test.dart
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart test test
```

Repository checks:

```bash
rg -n "src/(data|internal/transport|native_bridge|internal/testing)" \
  packages/nexa_http/lib packages/nexa_http/test .trellis/spec/nexa_http/dart docs/adr
git diff --check
```

Apple clean-host gate uses Catalog `verify-integration --execution apple-macos` with a local fixture URL and actual iOS/macOS device IDs. If implementation unexpectedly changes pubspec, bindings, carrier or artifact files, stop and expand verification before commit.

## TDD And Validation Evidence

- Baseline: package format、analyze和原有package suite通过。
- RED 1: 首版dependency contract在旧拓扑上因四个legacy目录仍存在、目标feature目录不存在而失败。
- GREEN 1: 19文件原子移动、import cutover和facade装配下沉后，dependency、lease、factory、cancellation、ownership和public surface focused suites通过。
- RED 2: review fixture证明首版directive regex错误读取block comment/multiline string，并漏掉conditional、export和part URI。
- GREEN 2: 最终4项dependency tests扫描整个 `lib/` directive前缀，覆盖root、conditional、comment和interpolation边界；package analyze与最终97项tests通过。
- Codegen: `build_runner build --delete-conflicting-outputs`通过；新路径4个generated outputs与移动前逐字一致，旧output不存在。
- Repository static gate: `verify-static --execution static-linux` 的7/7 checks通过；报告 `/tmp/nexa-http-dart-transport-static-final.json`。
- Apple integration gate: `verify-integration --execution apple-macos` 的5/5 checks通过；iOS simulator与macOS runtime的request、callback、body consume/release和client close均为true；报告 `/tmp/nexa-http-dart-transport-apple-report.json`。
- Final hygiene: production/current spec/ADR legacy search只命中dependency test拒绝常量；archived tasks零diff；generated bindings、C ABI、pubspec、carrier/artifact files零diff；`git diff --check`通过。

## Risky Areas

- Freezed/json_serializable generated file relocation and stale old outputs.
- Request body backing-buffer identity and one-copy dispatch budget.
- Binary result/body exactly-once release and mapper handoff.
- Cancel-vs-callback pending registry drain and `NativeCallable` disposal.
- Lazy lease open failure/retry, repeated execution reuse and close/dispose exactly once.
- Tests or current docs retaining legacy import paths after production moves.

## Rollback Points

- Keep the RED dependency test when it describes the intended durable boundary.
- The 19-file move is atomic; rollback by reverting the complete change, never by adding forwarders.
- Any behavior-test regression must be explained before changing lifecycle code; directory cleanup alone does not authorize behavior redesign.

## Review Gate

Repository evidence answers all scope questions, and the user's automatic-completion instruction is explicit approval to proceed once these artifacts are complete.
