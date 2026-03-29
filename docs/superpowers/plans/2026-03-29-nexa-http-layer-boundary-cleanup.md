# Nexa HTTP Layer Boundary Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten `nexa_http` layer boundaries without changing transport behavior by removing cross-package private imports, fixing native artifact resolution order, and clarifying legacy package status.

**Architecture:** Keep the current `public API -> transport bridge -> platform carrier -> native core` execution path intact. The cleanup focuses on making platform packages depend on a stable public runtime-registration API, correcting local-versus-manifest artifact selection order, and removing or explicitly isolating stale `rust_net*` remnants from the active workspace mental model.

**Tech Stack:** Dart, Flutter federated plugins, FFI, Rust native core, workspace scripts

---

### Task 1: Expose a public runtime registration boundary

**Files:**
- Create: `packages/nexa_http/lib/nexa_http_native_runtime.dart`
- Modify: `packages/nexa_http/lib/nexa_http.dart`
- Modify: `packages/nexa_http/lib/src/loader/nexa_http_platform_registry.dart`
- Test: `packages/nexa_http/test/...` registration or loader tests

- [ ] **Step 1: Add a public runtime-registration entrypoint**
- [ ] **Step 2: Export the new entrypoint from `packages/nexa_http/lib/nexa_http.dart`**
- [ ] **Step 3: Keep `platform_registry.dart` as an internal implementation detail and route public calls through it**
- [ ] **Step 4: Use a public API shape such as `registerNexaHttpNativeRuntime(...)` instead of exposing direct singleton mutation**
- [ ] **Step 5: Add or update a focused test proving that a registered runtime is visible to the loader**

### Task 2: Remove platform-package imports of `package:nexa_http/src/...`

**Files:**
- Modify: `packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart`
- Modify: `packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart`
- Modify: `packages/nexa_http_native_linux/lib/src/nexa_http_native_linux_plugin.dart`
- Modify: `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart`
- Modify: `packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart`

- [ ] **Step 1: Replace each platform package import of `package:nexa_http/src/...` with the new public registration entrypoint**
- [ ] **Step 2: Replace direct `NexaHttpPlatformRegistry.instance ??=` mutations with the public registration API**
- [ ] **Step 3: Preserve each platform-specific dynamic-library lookup path exactly as-is**
- [ ] **Step 4: Run targeted analysis on the platform packages to catch visibility or import regressions**

### Task 3: Fix native artifact resolution precedence

**Files:**
- Modify: `packages/nexa_http/lib/src/native_asset/nexa_http_native_artifact_resolver.dart`
- Modify: resolver tests under `packages/nexa_http/test/`

- [ ] **Step 1: Add or update tests to cover the intended precedence order**
- [ ] **Step 2: Make the precedence explicit: `explicit lib path -> explicit source dir -> packaged artifact -> default source dir/build -> manifest download`**
- [ ] **Step 3: Remove the current behavior where `defaultSourceDir` can trigger premature manifest preference**
- [ ] **Step 4: Re-run the resolver-focused tests and verify local fallback behavior still works**
- [ ] **Step 5: Add a short code comment documenting the precedence so future edits do not reintroduce the bug**

### Task 4: Clarify or remove legacy `rust_net*` remnants

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Optional delete/move: `packages/rust_net`
- Optional delete/move: `packages/rust_net_core`
- Optional delete/move: `packages/rust_net_native_ios`

- [ ] **Step 1: Search scripts, CI, and docs for references to the `rust_net*` directories**
- [ ] **Step 2: If the directories are unused, remove them or move them into an explicit archive location**
- [ ] **Step 3: If they cannot be removed yet, document clearly that the active workspace packages are the `nexa_http*` packages**
- [ ] **Step 4: Update developer-facing docs so new contributors do not mistake the legacy directories for current implementation layers**

### Task 5: Verify the workspace after the boundary cleanup

**Files:**
- Verify only

- [ ] **Step 1: Run `fvm dart test` in `packages/nexa_http`**
- [ ] **Step 2: Run `fvm flutter test` in `packages/nexa_http/example`**
- [ ] **Step 3: Run `fvm dart run scripts/workspace_tools.dart analyze` at the workspace root**
- [ ] **Step 4: Run `rg "package:nexa_http/src/" packages/nexa_http_native_*` and confirm there are no remaining private-package imports**
- [ ] **Step 5: Inspect `git diff --stat` to confirm the changes stay limited to registration boundaries, resolver logic, and docs/legacy cleanup**
