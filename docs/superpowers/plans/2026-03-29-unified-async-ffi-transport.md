# Unified Async FFI Transport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify all platforms on one async FFI request pipeline and remove remaining Android-specific execution concepts from the shared Dart bridge.

**Architecture:** The shared Dart layer will always dispatch requests through `nexa_http_client_execute_async`, and `native core` will remain the only shared execution engine. Platform carriers and platform native modules will keep only legitimate platform responsibilities such as native library loading, proxy state, and packaged/workspace asset discovery.

**Tech Stack:** Dart, Flutter, Rust, FFI, reqwest, workspace scripts, generated bindings

---

### Task 1: Remove Android-only execution branching from the shared Dart data source

**Files:**
- Modify: `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- Test: `packages/nexa_http/test/ffi_nexa_http_native_data_source_test.dart`

- [ ] Step 1: Write or update failing tests that assert the shared data source no longer needs binary-execution configuration.
- [ ] Step 2: Run `fvm dart test test/ffi_nexa_http_native_data_source_test.dart` in `packages/nexa_http` and confirm the old binary-path expectations fail.
- [ ] Step 3: Remove `preferSynchronousExecution`, `binaryExecutor`, `binaryExecutionLibraryPath`, `_BinaryExecuteRequest`, `_executeBinaryInBackgroundIsolate`, and the synchronous-only decode helpers from `ffi_nexa_http_native_data_source.dart`.
- [ ] Step 4: Make `execute()` always allocate `NativeHttpRequestArgs`, call `nexa_http_client_execute_async`, and decode through the callback path.
- [ ] Step 5: Re-run `fvm dart test test/ffi_nexa_http_native_data_source_test.dart` in `packages/nexa_http` and confirm it passes.
- [ ] Step 6: Commit with `git commit -m "refactor(nexa_http): remove binary request execution path"`.

### Task 2: Shrink the public runtime contract to native-library loading only

**Files:**
- Modify: `packages/nexa_http/lib/src/loader/nexa_http_native_runtime.dart`
- Modify: `packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart`
- Modify: `packages/nexa_http/lib/src/loader/nexa_http_native_library_loader.dart`
- Modify: `packages/nexa_http/test/nexa_http_native_data_source_factory_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_native_library_loader_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_platform_registry_test.dart`

- [ ] Step 1: Write or update failing tests that assert the runtime contract only needs `open()`.
- [ ] Step 2: Run the focused Dart tests for factory and loader files and confirm the old runtime shape is still required.
- [ ] Step 3: Remove `binaryExecutionLibraryPath` from `NexaHttpNativeRuntime`.
- [ ] Step 4: Update `NexaHttpNativeDataSourceFactory` so it only loads the library and creates the shared FFI data source without any Android-only execution parameters.
- [ ] Step 5: Re-run the focused Dart tests and confirm they pass with the reduced runtime contract.
- [ ] Step 6: Commit with `git commit -m "refactor(nexa_http): simplify native runtime contract"`.

### Task 3: Remove the binary-execution preference symbol from native modules and generated bindings

**Files:**
- Modify: `packages/nexa_http/lib/nexa_http_bindings_generated.dart`
- Modify: `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/lib.rs`
- Modify: `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs`
- Modify: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs`
- Modify: `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/lib.rs`
- Modify: native-binding generation config if needed
- Test: carrier crate tests as needed

- [ ] Step 1: Regenerate or update bindings/tests so the old `nexa_http_runtime_prefers_binary_execution` symbol is no longer referenced.
- [ ] Step 2: Run the affected Dart and Rust tests and confirm the workspace still expects the old symbol.
- [ ] Step 3: Remove `nexa_http_runtime_prefers_binary_execution()` exports from all platform native crates.
- [ ] Step 4: Regenerate `packages/nexa_http/lib/nexa_http_bindings_generated.dart` so the symbol lookup disappears from the public package.
- [ ] Step 5: Re-run focused Rust crate tests for Android, iOS, macOS, and Windows, plus the relevant Dart tests, and confirm they pass.
- [ ] Step 6: Commit with `git commit -m "refactor(nexa_http): remove runtime execution preference symbol"`.

### Task 4: Clean up carrier-side platform runtime implementations

**Files:**
- Modify: `packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart`
- Modify: `packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart`
- Modify: `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart`
- Modify: `packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart`
- Test: `packages/nexa_http_native_android/test/nexa_http_native_android_plugin_test.dart`
- Test: `packages/nexa_http_native_ios/test/nexa_http_native_ios_plugin_test.dart`
- Test: `packages/nexa_http_native_macos/test/nexa_http_native_macos_plugin_test.dart`
- Test: `packages/nexa_http_native_windows/test/nexa_http_native_windows_plugin_test.dart`

- [ ] Step 1: Update carrier tests so they validate only registration and native library loading behavior.
- [ ] Step 2: Run the focused carrier plugin tests and confirm any binary-path expectations fail.
- [ ] Step 3: Remove Android-only `binaryExecutionLibraryPath` handling from carrier runtime implementations.
- [ ] Step 4: Keep legitimate packaged/workspace/native-library discovery behavior intact for desktop and mobile runtimes.
- [ ] Step 5: Re-run the carrier plugin tests and confirm they pass.
- [ ] Step 6: Commit with `git commit -m "refactor(nexa_http): keep carriers focused on runtime loading"`.

### Task 5: Update docs and verification around the unified transport model

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`
- Modify: `docs/superpowers/specs/2026-03-29-unified-async-ffi-transport-design.md` if implementation wording needs to be tightened

- [ ] Step 1: Update README content so the implementation description states that all platforms now use one async FFI transport path.
- [ ] Step 2: Remove any lingering wording about Android-specific binary execution or runtime execution preference.
- [ ] Step 3: Run the full verification set:
  - `cargo test --workspace`
  - `fvm dart test` in `packages/nexa_http`
  - `env PUB_HOSTED_URL=https://pub.dev FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com fvm flutter test` in `packages/nexa_http/example`
  - `fvm dart run scripts/workspace_tools.dart analyze`
- [ ] Step 4: Run search checks:
  - `rg "preferSynchronousExecution|binaryExecutionLibraryPath|nexa_http_runtime_prefers_binary_execution|_executeBinaryInBackgroundIsolate" packages/nexa_http packages/nexa_http_native_* native -g '*.dart' -g '*.rs'`
- [ ] Step 5: Confirm `git diff --stat` is limited to the shared Dart bridge, platform runtimes, bindings, tests, and docs.
- [ ] Step 6: Commit with `git commit -m "docs(readme): describe unified async ffi transport"` if documentation is separated, otherwise include docs in the final feature commit.
