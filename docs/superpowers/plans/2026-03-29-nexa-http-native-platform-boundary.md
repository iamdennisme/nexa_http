# Nexa HTTP Native Platform Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `nexa_http` a pure consumer of the native protocol by removing concrete platform branching from the Dart public layer and pushing platform differences behind native core and native platform modules.

**Architecture:** The Dart side should only know the common request/response ABI, dynamic-library registration, and generic FFI transport wiring. All platform-specific behavior, including execution-mode differences and system/platform capability handling, must be expressed either through the native core contract or in the platform-native modules, not through `Platform.isAndroid`-style branching in `packages/nexa_http/lib`.

**Tech Stack:** Dart, Flutter federated plugins, FFI, Rust native core, platform-native Rust crates, package-level tests

---

### Task 1: Identify and lock down Dart-side platform leakage

**Files:**
- Inspect: `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- Inspect: `packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart`
- Inspect: `packages/nexa_http/lib/src/loader/nexa_http_native_library_loader.dart`
- Inspect: `packages/nexa_http_native_*/lib/src/*.dart`
- Test: `packages/nexa_http/test/`

- [ ] **Step 1: Enumerate every concrete platform branch that still exists under `packages/nexa_http/lib`**
- [ ] **Step 2: Separate acceptable registration/loading concerns from unacceptable platform-behavior concerns**
- [ ] **Step 3: Add or update focused tests that fail if the common package still relies on concrete platform branching for execution behavior**
- [ ] **Step 4: Confirm the failing tests target behavior, not implementation trivia**

### Task 2: Move execution-mode differences behind the native contract

**Files:**
- Modify: `native/nexa_http_native_core/src/api/ffi.rs`
- Modify: `native/nexa_http_native_core/src/runtime/executor.rs`
- Modify: platform-native Rust crates under:
  - `packages/nexa_http_native_android/native/...`
  - `packages/nexa_http_native_ios/native/...`
  - `packages/nexa_http_native_macos/native/...`
  - `packages/nexa_http_native_linux/native/...`
  - `packages/nexa_http_native_windows/native/...`
- Test: Rust tests and Dart FFI tests that cover execution path behavior

- [ ] **Step 1: Decide what the native core contract must expose so Dart no longer needs to choose execution behavior by platform**
- [ ] **Step 2: Add the minimal ABI or runtime-contract change needed to represent that behavior generically**
- [ ] **Step 3: Implement the platform-specific behavior in the native platform modules, not in Dart**
- [ ] **Step 4: Preserve current runtime semantics while removing the need for Dart-side platform branching**
- [ ] **Step 5: Add or update native tests to verify the contract remains consistent across platforms**

### Task 3: Simplify the Dart bridge to consume only the common contract

**Files:**
- Modify: `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- Modify: `packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart`
- Modify: `packages/nexa_http/lib/src/loader/nexa_http_native_runtime.dart`
- Modify: `packages/nexa_http/lib/src/loader/nexa_http_platform_registry.dart`
- Test: `packages/nexa_http/test/ffi_nexa_http_native_data_source_test.dart`
- Test: `packages/nexa_http/test/nexa_http_native_data_source_factory_test.dart`

- [ ] **Step 1: Remove concrete platform checks such as `Platform.isAndroid` from the common Dart bridge**
- [ ] **Step 2: Remove hard-coded platform library-name assumptions from the common execution path**
- [ ] **Step 3: Keep only generic runtime registration and generic dynamic-library opening concerns in the Dart layer**
- [ ] **Step 4: Update the factory and FFI tests to prove the Dart side now only consumes the common native contract**
- [ ] **Step 5: Re-run focused Dart tests and confirm behavior stays green**

### Task 4: Reduce Dart platform packages to registration and packaging concerns

**Files:**
- Modify: `packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart`
- Modify: `packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart`
- Modify: `packages/nexa_http_native_linux/lib/src/nexa_http_native_linux_plugin.dart`
- Modify: `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart`
- Modify: `packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart`
- Modify if needed: `packages/nexa_http_native_*/hook/build.dart`
- Test: platform-package plugin and build-hook tests

- [ ] **Step 1: Keep Dart platform packages focused on runtime registration, library discovery, and artifact packaging**
- [ ] **Step 2: Remove any remaining behavior decisions that belong in native platform code instead of Dart plugin code**
- [ ] **Step 3: Preserve the ability for platform packages to locate and register their native binary without expanding common-package responsibilities**
- [ ] **Step 4: Run targeted plugin and hook tests for the touched platform packages**

### Task 5: Re-document the project boundary model

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`

- [ ] **Step 1: Document that `nexa_http` is the common Dart API and protocol consumer, not the owner of platform behavior**
- [ ] **Step 2: Document that native core defines the shared contract and native platform modules implement platform differences**
- [ ] **Step 3: Keep the Dart platform packages described as registration and packaging layers**

### Task 6: Verify the boundary cleanup end to end

**Files:**
- Verify only

- [ ] **Step 1: Run `cargo test` for the touched native crates or the relevant Rust workspace targets**
- [ ] **Step 2: Run `fvm dart test` in `packages/nexa_http`**
- [ ] **Step 3: Run `fvm flutter test` in `packages/nexa_http/example`**
- [ ] **Step 4: Run `fvm dart run scripts/workspace_tools.dart analyze` at the workspace root**
- [ ] **Step 5: Run `rg -n "Platform\\.isAndroid|Platform\\.isIOS|Platform\\.isMacOS|Platform\\.isLinux|Platform\\.isWindows" packages/nexa_http/lib` and confirm the common Dart package no longer contains concrete platform behavior branches**
- [ ] **Step 6: Inspect `git diff --stat` to confirm the refactor stayed within native contract changes, Dart bridge cleanup, platform registration code, and docs**
