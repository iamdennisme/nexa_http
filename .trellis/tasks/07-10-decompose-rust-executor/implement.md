# Decompose Rust executor - Implementation Plan

## Preconditions

- [x] User authorized automatic completion of all outstanding tasks.
- [x] Run `task.py start` only after planning artifacts are written and reviewed against source/spec evidence.
- [x] Load `trellis-before-dev` for core runtime/API specs before product edits.

## Ordered Checklist

- [x] Record core/workspace test, fmt and strict Clippy baseline.
- [x] RED: add `runtime_module_boundaries.rs` for the planned owners; confirm missing modules/forbidden executor definitions fail.
- [x] Extract `api/ffi_types.rs` as the stable layout leaf while preserving `api::ffi::*` re-export paths.
- [x] Extract `api/ffi_decode.rs`; move decode tests and keep request-body adoption/copy semantics.
- [x] Extract `api/ffi_result.rs`; route runtime and FFI test helper through one free implementation.
- [x] Deepen `client_registry.rs` to own map/IDs/build/refresh; keep refresh tests green.
- [x] Extract `runtime/inflight.rs`; move state transitions and state-local tests; keep callback-commit integration green.
- [x] Extract `runtime/request_execution.rs`; move HTTP projection/error mapping and source-chain test.
- [x] Reduce `executor.rs` to facade/orchestration and move its behavior tests to `runtime/executor/tests.rs`.
- [x] Remove obsolete imports/helpers/types; apply minimum visibility and verify no child imports executor.
- [x] Run `trellis-update-spec` for the durable runtime/API ownership map.
- [x] Run final validation, update acceptance/TDD evidence, commit and archive task.

## TDD And Validation Evidence

- RED：`runtime_module_boundaries.rs` 因缺少 `inflight.rs` / `request_execution.rs` 且 executor仍拥有被禁止职责而失败。
- GREEN：每次抽取后运行 core unit tests与strict Clippy；最终 core含17个owner-local unit tests、21个integration tests及2个module boundary tests。
- Workspace：`cargo fmt --all -- --check`、`cargo clippy --workspace --all-targets -- -D warnings`、`cargo test --workspace`通过。
- ABI：`fvm dart test test/native_ffi_abi_contract_test.dart` 的4个contract tests通过；header、generated bindings和四个平台wrapper无diff。
- Apple：`verify-integration --execution apple-macos`通过全部5个checks；报告 `/tmp/nexa-http-executor-apple-report.json`，iOS/macOS runtime payload的request/callback/body release/client close均为true。

## Validation Commands

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test -p nexa_http_native_core
cargo test --workspace
fvm dart test test/native_ffi_abi_contract_test.dart
```

Architecture searches:

```bash
rg -n "fn (read_client_config|read_request|build_binary_success_result|build_binary_error_result|map_reqwest_error)|enum InflightRequestState|Mutex<HashMap<u64, ClientEntry>>" native/nexa_http_native_core/src/runtime/executor.rs
rg -n "runtime::executor" native/nexa_http_native_core/src --glob '*.rs'
```

The first command must return no production responsibility definitions. The second may only find the public runtime re-export/module declaration, never a child-module import or result free back edge.

Run Apple integration execution with the local fixture server and actual iOS/macOS device IDs after Rust/ABI gates pass.

## Risky Files

- `native/nexa_http_native_core/src/runtime/executor.rs`
- `native/nexa_http_native_core/src/runtime/client_registry.rs`
- new runtime/API module files and `src/lib.rs`
- `native/nexa_http_native_core/src/api/ffi.rs`
- runtime/decode/result tests and module-boundary contract
- core directory/error/quality specs

## Rollback Points

- After each mechanical move, run focused tests before the next responsibility.
- Preserve exact state transitions and free order; any behavior change returns to the last green extraction.
- Do not edit C header, generated bindings, platform `lib.rs` or public Dart sources.

## Review Gate

Automatic user authorization satisfies the implementation approval gate once these artifacts match the inspected source and specs.
