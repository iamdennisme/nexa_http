# Deepen platform FFI export glue - Implementation Plan

## Preconditions

- Keep the Trellis task in `planning` until this plan is reviewed and `task.py start` is explicitly approved.
- Before editing Phase 2 code, load `trellis-before-dev` for the core, all four platform FFI crates, workspace tooling, and Flutter SDK contract scopes.
- Record baseline `git status`, focused Rust tests, and the checked-in generated binding state. Do not absorb unrelated worktree changes.

## Ordered Implementation

### 1. Establish The First RED

- Add a focused root test for the canonical nine public ABI symbol names.
- Compare the canonical list with C header declarations, generated Dart lookup entries, and Android's source-build symbol safety list.
- Run only the focused test and record that it fails because Android currently checks six of the nine public symbols.
- Do not change platform wrappers before this RED is observed.

### 2. Make The ABI Source Contract GREEN

- Add the small reusable ABI-contract helper under `scripts/`.
- Complete Android's required-symbol safety list with `nexa_http_take_last_error_json`, `nexa_http_string_free`, and `nexa_http_client_close`.
- Keep the check as an exact public-symbol contract, with `nexa_http_test_*` explicitly excluded from the public set.
- Rerun the focused contract test.

### 3. Establish The Consolidation RED

- Extend the focused contract test to require one shared export macro invocation in each platform `src/lib.rs` and reject local `#[unsafe(no_mangle)]` wrapper definitions.
- Run it against the explicit wrappers and record the expected failure.

### 4. Add The Core Export Macro

- Add `native/nexa_http_native_core/src/api/ffi_exports.rs` and register the module from `src/lib.rs`.
- Implement the named `export_nexa_http_ffi!` invocation contract with `$crate`-qualified paths.
- Emit all nine wrappers with signatures matching the design table.
- Add a private typed runtime accessor to bind the runtime expression to the declared platform-state type.
- Add compile-time `extern "C" fn` coercion assertions for all nine emitted functions.
- Keep the existing test-only exports in `api/ffi.rs` unchanged.
- Run core tests and formatting before touching all platform crates.

### 5. Migrate Platform Crates

- Replace Android's nine wrappers with one macro invocation; preserve its polling runtime initializer exactly.
- Replace iOS, macOS, and Windows wrappers with one invocation each; preserve their construction-boundary runtime initializers exactly.
- Remove only imports made obsolete by macro expansion.
- Run each platform crate test independently, then run the workspace Rust suite.
- Rerun the consolidation contract test and confirm it is GREEN.

### 6. Add Concrete Symbol Verification

- Add unit-tested symbol parsing/normalization for ELF, Mach-O, and PE tool output.
- Add `verify-native-abi` to `scripts/workspace_tools.dart` and its command list/usage.
- Resolve current-runner packaged artifacts from the existing target matrix and fail on a missing expected artifact.
- Compare normalized non-test `nexa_http_*` exports exactly with the canonical nine-symbol list.
- Include target, artifact, command, missing symbols, and unexpected symbols in failures.
- Update root workspace-tool tests for command routing and parser behavior.

### 7. Wire Platform CI

- In Ubuntu CI, regenerate Dart bindings from `nexa_http_native.h` with the pinned package dependencies and require no whitespace-insensitive semantic diff in `nexa_http_bindings_generated.dart`; formatter-only wrapping is tolerated while declaration drift is not.
- In Ubuntu CI, run the verifier after `build_native_android.sh` and inspect all three Android ABIs with NDK `llvm-nm`.
- In macOS CI, run it after both Apple build scripts and inspect the packaged macOS and three iOS outputs with `nm`.
- In Windows CI, run it after `build_native_windows.sh` and inspect the DLL with `dumpbin` or the declared fallback.
- Keep artifact preparation, clean-host verification, target matrices, and release staging unchanged.

### 8. Verify Generated And Runtime Contracts

- Run ffigen from `packages/nexa_http` and require no whitespace-insensitive declaration diff in `lib/nexa_http_bindings_generated.dart`; restore formatter-only output so the checked-in binding remains unchanged.
- Run core ownership/runtime tests and the Dart FFI data-source/finalizer tests.
- Run all four carrier build-hook tests separately because they mutate `Directory.current`.
- Run formatting, full workspace Rust tests, workspace Dart tests, artifact consistency, development-path verification, and external-consumer verification.
- Record target-specific checks that require Ubuntu/Android or Windows runners when working locally on macOS.

### 9. Review And Finish

- Review the diff for accidental header, generated binding, artifact filename, runtime initializer, proxy source, or host integration changes.
- Run `trellis-check` for the final quality gate.
- Update the core/platform Trellis specs with the shared export-macro and ABI verification contract if the implementation confirms the design.
- Commit and archive only after the required checks pass and the user approves the completed implementation.

## Validation Commands

### Focused RED/GREEN

```bash
fvm dart test test/native_ffi_abi_contract_test.dart
cargo test -p nexa_http_native_core
cargo test -p nexa_http_native_android_ffi
cargo test -p nexa_http_native_ios_ffi
cargo test -p nexa_http_native_macos_ffi
cargo test -p nexa_http_native_windows_ffi
```

### Rust Quality Gate

```bash
cargo fmt --all --check
cargo test --workspace
```

### Dart And Generated Binding Gate

```bash
fvm dart test test/native_ffi_abi_contract_test.dart
fvm dart test test/workspace_tools_test.dart
fvm dart test test/workspace_demo_and_consumer_verification_test.dart
fvm dart test test/workspace_release_consistency_test.dart
(cd packages/nexa_http && fvm dart run ffigen --config ffigen.yaml)
git diff --ignore-all-space --exit-code -- packages/nexa_http/lib/nexa_http_bindings_generated.dart
(cd packages/nexa_http && fvm dart test test/ffi_nexa_http_native_data_source_test.dart)
```

### Carrier And Clean-Host Gate

```bash
(cd packages/nexa_http_native_android && fvm dart test test/build_hook_test.dart)
(cd packages/nexa_http_native_ios && fvm dart test test/build_hook_test.dart)
(cd packages/nexa_http_native_macos && fvm dart test test/build_hook_test.dart)
(cd packages/nexa_http_native_windows && fvm dart test test/build_hook_test.dart)
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

### Platform Artifact Gate

```bash
# macOS runner
./scripts/build_native_macos.sh debug
./scripts/build_native_ios.sh debug
fvm dart run scripts/workspace_tools.dart verify-native-abi

# Ubuntu runner with Android NDK
./scripts/build_native_android.sh debug
fvm dart run scripts/workspace_tools.dart verify-native-abi

# Windows runner
./scripts/build_native_windows.sh debug
fvm dart run scripts/workspace_tools.dart verify-native-abi
```

## Review Gates

- Gate 1: first RED demonstrates the current incomplete Android ABI safety list.
- Gate 2: all four crates compile the shared macro with unchanged runtime initializers.
- Gate 3: header, generated bindings, and canonical symbol list agree.
- Gate 4: concrete artifacts expose exactly the nine non-test public symbols.
- Gate 5: clean-host consumers need only standard dependencies, public import, and Flutter build commands.

## Implementation Evidence

- RED 1: `native_ffi_abi_contract_test.dart` found Android's six-symbol list missing `nexa_http_take_last_error_json`, `nexa_http_string_free`, and `nexa_http_client_close`.
- GREEN 1: the shared nine-symbol contract and completed Gradle list passed.
- RED 2: all four platform crates lacked the required shared macro invocation.
- GREEN 2: `export_nexa_http_ffi!` compiled in all four crates; focused crate tests and the structural contract passed.
- RED/GREEN 3: symbol parser and exact public-set comparison were added from failing compile tests, including test-symbol exclusion.
- RED/GREEN 4: native artifact verifier, CI routing, CI contract tests, and issue-ready error fields were each introduced behind focused failing tests.
- macOS evidence: rebuilt one macOS and three iOS artifacts; `verify-native-abi` passed against their real Mach-O exports.
- Cross-runner evidence: CI now builds and inspects all Android ABIs on Ubuntu and the x64 DLL on Windows; parser/tool fallback behavior is unit tested locally.
- Compatibility evidence: strict repository diff confirms no C header or generated Dart binding change; ffigen regeneration has only formatter whitespace changes under the pinned SDK.
- Host evidence: all carrier hook suites, `verify-artifact-consistency`, `verify-development-path`, and `verify-external-consumer` passed on macOS. Android and Windows native hook branches remain assigned to their CI hosts.

## Risky Files And Rollback Points

- `native/nexa_http_native_core/src/api/ffi_exports.rs`: revert macro implementation if target expansion or hygiene fails; keep contract tests.
- Four platform `src/lib.rs` files: restore their explicit wrappers independently while preserving runtime initializers.
- `scripts/workspace_tools.dart` and CI workflow: remove only the new verifier routing if a platform tool adapter is unreliable; retain source-level ABI checks until the adapter is fixed.
- `packages/nexa_http_native_android/android/build.gradle`: the completed nine-symbol safety list is independently useful and should remain even if macro consolidation rolls back.
- No rollback should touch the C header, generated Dart binding, proxy implementations, carrier hooks, target matrix, or host projects.
