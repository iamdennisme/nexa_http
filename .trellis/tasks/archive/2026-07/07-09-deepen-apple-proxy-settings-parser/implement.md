# Deepen Apple proxy settings parser - Implementation Plan

## Checklist

- [x] Review `prd.md`, `design.md`, and this plan before starting.
- [x] Run `python3 ./.trellis/scripts/task.py start .trellis/tasks/07-09-deepen-apple-proxy-settings-parser` only after user approval.
- [x] Load `trellis-before-dev` before editing product code.
- [x] Read applicable specs:
  - `.trellis/spec/nexa_http_native_macos_ffi/backend/index.md`
  - `.trellis/spec/nexa_http_native_macos_ffi/backend/directory-structure.md`
  - `.trellis/spec/nexa_http_native_macos_ffi/backend/error-handling.md`
  - `.trellis/spec/nexa_http_native_macos_ffi/backend/quality-guidelines.md`
  - `.trellis/spec/nexa_http_native_ios_ffi/backend/index.md`
  - `.trellis/spec/nexa_http_native_ios_ffi/backend/directory-structure.md`
  - `.trellis/spec/nexa_http_native_ios_ffi/backend/error-handling.md`
  - `.trellis/spec/nexa_http_native_ios_ffi/backend/quality-guidelines.md`
  - `.trellis/spec/guides/tdd-development-policy.md`
  - `.trellis/spec/guides/project-layering-contract.md`
  - `.trellis/spec/guides/code-reuse-thinking-guide.md`
  - `.trellis/spec/guides/cross-layer-thinking-guide.md`
  - `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
- [x] RED: add one parser-level test for the planned shared Apple parser API.
- [x] GREEN: add `native/nexa_http_native_apple_proxy` as a workspace member with the minimum parser implementation.
- [x] Move parser helpers from macOS/iOS `proxy_source.rs` into the shared crate.
- [x] Update macOS/iOS `Cargo.toml` dependencies to use the shared parser crate.
- [x] Remove the macOS/iOS crates' direct `reqwest` dependency after repository search confirmed it was parser-only.
- [x] Update macOS/iOS `proxy_source.rs` to keep only platform adapter/SystemConfiguration code plus delegation.
- [x] Reduce duplicated iOS/macOS parser-rule tests; keep adapter integration and refresh mode coverage.
- [x] Run focused tests after each GREEN/refactor step.
- [x] Run final validation commands.
- [x] Run `trellis-update-spec` for the new durable native-layer crate boundary and update the package map/specs.
- [x] Record RED/GREEN/refactor commands and outcomes in the TDD Evidence section below.
- [x] Commit task changes after validation.

## Validation Commands

```bash
cargo fmt --all --check
cargo test -p nexa_http_native_apple_proxy
cargo test -p nexa_http_native_macos_ffi
cargo test -p nexa_http_native_ios_ffi
cargo test --workspace
fvm dart test packages/nexa_http_native_macos/test/build_hook_test.dart
fvm dart test packages/nexa_http_native_ios/test/build_hook_test.dart
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

The two consumer checks are the Flutter SDK contract gate: they prove that the new Rust dependency remains hidden behind the existing carrier, C ABI, and dynamic-library artifacts.

## Risky Files

- `Cargo.toml`
- `native/nexa_http_native_apple_proxy/**`
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml`
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/proxy_source.rs`
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/tests/proxy_settings.rs`
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/Cargo.toml`
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/proxy_source.rs`
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/tests/proxy_settings.rs`

## Rollback Points

- After RED test: if the shared parser API is awkward, revise design before implementation.
- After creating the crate: run `cargo test -p nexa_http_native_apple_proxy` before touching platform adapters.
- Before removing duplicated parser code: confirm the shared parser tests cover the rule being moved.
- Before changing any C ABI, artifact, carrier, Android, or Windows file: stop and revise planning.

## TDD Evidence

Record each vertical slice during implementation:

| Slice | RED command and expected failure | GREEN/refactor command and result |
|---|---|---|
| Shared parser contract | `cargo test -p nexa_http_native_apple_proxy --test proxy_settings enabled_http_proxy_uses_http_default_scheme` failed with exit 101 because `src/lib.rs` did not exist. Subsequent behavior tests failed on missing HTTPS/SOCKS mapping, quoted host cleanup, unsupported scheme handling, bypass canonicalization, and non-positive ports. | Each focused test passed after its minimum implementation; final shared parser result: 8 tests passed. |
| Platform adapter migration | Baseline iOS/macOS suites passed 5 tests each before refactor. | Shared + iOS + macOS suites passed after delegation; parser rules now live in 8 shared tests and each platform keeps 3 adapter/runtime tests. |
| Proxy test environment isolation | Plain `cargo test --workspace` exposed two existing assertions that treated `PlatformRuntimeView` as an unmerged raw snapshot while the shell provided proxy env values. | Tests now use `current_proxy_snapshot()` for raw state or avoid environment-dependent effective-proxy assertions; plain `cargo test --workspace` passes with the host proxy environment intact. |

## Verification Results

- `cargo fmt --all --check`: passed.
- `cargo clippy --no-deps -p nexa_http_native_apple_proxy --all-targets -- -D warnings`: passed.
- `cargo test -p nexa_http_native_apple_proxy -p nexa_http_native_macos_ffi -p nexa_http_native_ios_ffi`: passed.
- `cargo test --workspace`: passed.
- macOS build-hook tests: 3 passed.
- iOS build-hook tests: 2 passed.
- `verify-development-path`: passed, including macOS debug and iOS simulator debug builds.
- `verify-external-consumer`: passed for a clean macOS Flutter host fixture.

Full workspace Clippy is not a repository gate for this task and still reports pre-existing FFI lints in unchanged raw-pointer APIs and compatibility helpers. The new crate passes strict Clippy with warnings denied.

## Review Gate

Planning is ready when:

- `prd.md` defines behavior preservation and scope.
- `design.md` describes the shared parser crate and platform adapter boundaries.
- `design.md` maps the change against the Flutter SDK authoring contract.
- `implement.md` defines RED/GREEN/refactor, native validation, and clean-host consumer commands.

Do not start implementation until the user explicitly approves proceeding from planning to implementation.
