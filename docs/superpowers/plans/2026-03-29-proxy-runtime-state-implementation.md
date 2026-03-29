# Proxy Runtime State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace probe-based proxy refresh in `native core` with platform-owned proxy runtime state and generation-based client rebuilds.

**Architecture:** `native core` will stop polling for proxy drift and instead consume a read-only platform runtime state contract that exposes the current proxy snapshot and a monotonically increasing generation. Each platform runtime will own its local proxy state implementation, starting with snapshot + generation wiring in phase 1 and leaving true platform event listeners for phase 2.

**Tech Stack:** Rust, reqwest, once_cell, std sync primitives, Flutter carrier runtimes, Dart workspace tests

---

### Task 1: Introduce the runtime state contract in native core

**Files:**
- Modify: `native/nexa_http_native_core/src/platform/capabilities.rs`
- Modify: `native/nexa_http_native_core/src/platform/mod.rs`
- Modify: `native/nexa_http_native_core/src/platform/proxy.rs`
- Test: `native/nexa_http_native_core/tests/proxy_runtime.rs`

- [ ] Step 1: Write the failing native-core test for generation-aware runtime state

Add or extend a test in `native/nexa_http_native_core/tests/proxy_runtime.rs` that uses a fake platform state with:
- an initial `ProxySettings::default()`
- a mutable generation counter
- a changed proxy snapshot after the generation increments

The test should assert:
- unchanged generation does not force a rebuild
- changed generation is observable by the runtime state

- [ ] Step 2: Run the proxy runtime test to verify it fails for the missing runtime-state contract

Run: `cargo test --manifest-path native/nexa_http_native_core/Cargo.toml --test proxy_runtime`
Expected: FAIL because the existing trait only exposes `proxy_settings()`

- [ ] Step 3: Replace the old capability trait with a runtime-state contract

Update `native/nexa_http_native_core/src/platform/capabilities.rs` so the platform contract exposes:

```rust
pub trait PlatformRuntimeState: Send + Sync + 'static {
    fn current_proxy_snapshot(&self) -> ProxySettings;
    fn proxy_generation(&self) -> u64;

    fn platform_features(&self) -> PlatformFeatures {
        PlatformFeatures::with_env_fallback(self.current_proxy_snapshot())
    }
}
```

Update exports in `native/nexa_http_native_core/src/platform/mod.rs` to re-export the renamed trait.

- [ ] Step 4: Adjust proxy runtime tests and helpers to compile with the new contract

Update all fake capabilities in `native/nexa_http_native_core/tests/proxy_runtime.rs` and any helper usage in `native/nexa_http_native_core/src/platform/proxy.rs` tests to implement:
- `current_proxy_snapshot()`
- `proxy_generation()`

Use atomic counters for generation in test doubles.

- [ ] Step 5: Re-run the proxy runtime test to verify it passes

Run: `cargo test --manifest-path native/nexa_http_native_core/Cargo.toml --test proxy_runtime`
Expected: PASS

- [ ] Step 6: Commit the runtime-state trait change

```bash
git add native/nexa_http_native_core/src/platform/capabilities.rs \
  native/nexa_http_native_core/src/platform/mod.rs \
  native/nexa_http_native_core/src/platform/proxy.rs \
  native/nexa_http_native_core/tests/proxy_runtime.rs
git commit -m "refactor(nexa_http): add platform runtime state contract"
```

### Task 2: Replace probe-based client refresh with generation-based refresh

**Files:**
- Modify: `native/nexa_http_native_core/src/runtime/client_registry.rs`
- Modify: `native/nexa_http_native_core/src/runtime/executor.rs`
- Test: `native/nexa_http_native_core/src/runtime/executor.rs`
- Test: `native/nexa_http_native_core/tests/runtime_smoke.rs`

- [ ] Step 1: Write the failing native-core tests for generation-driven client reuse and rebuild

In `native/nexa_http_native_core/src/runtime/executor.rs` test module, add focused tests that verify:
- unchanged generation reuses the existing client
- incremented generation rebuilds once
- repeated requests after rebuild stay on the fast path

The tests should use a fake runtime state with:
- mutable snapshot
- mutable generation
- counters for snapshot reads and generation reads

- [ ] Step 2: Run the executor-focused tests to verify they fail for the existing probe model

Run: `cargo test --manifest-path native/nexa_http_native_core/Cargo.toml runtime::executor`
Expected: FAIL because the current implementation still relies on `needs_refresh`, `refresh_in_progress`, and time-based probes

- [ ] Step 3: Simplify `ClientEntry` to store proxy generation instead of probe bookkeeping

In `native/nexa_http_native_core/src/runtime/client_registry.rs`, replace:
- `platform_features_signature`
- `needs_refresh`
- `refresh_in_progress`
- `next_refresh_probe_at`

with a smaller shape:
- `platform_features_signature`
- `proxy_generation`

Keep the stored signature if it is still useful for avoiding redundant rebuilds inside the same generation.

- [ ] Step 4: Update `create_client()` to store generation from platform runtime state

In `native/nexa_http_native_core/src/runtime/executor.rs`, change client creation so it:
- reads `platform_features()`
- reads `proxy_generation()`
- stores the generation on the client entry

- [ ] Step 5: Replace refresh-probe logic with generation comparison in request execution

Update `execute_request()` and `refresh_client_and_clone()` so request handling becomes:
- read current generation
- compare with stored generation
- if unchanged, reuse client directly
- if changed, read the latest snapshot, rebuild once, update generation, continue

Remove the probe interval and failure backoff logic if they are no longer needed.

- [ ] Step 6: Update runtime smoke tests to match the new model

Adjust `native/nexa_http_native_core/tests/runtime_smoke.rs` so it asserts stable request reuse without referring to probe windows or refresh backoff behavior.

- [ ] Step 7: Re-run executor and runtime smoke tests to verify they pass

Run:
- `cargo test --manifest-path native/nexa_http_native_core/Cargo.toml runtime::executor`
- `cargo test --manifest-path native/nexa_http_native_core/Cargo.toml --test runtime_smoke`

Expected: PASS

- [ ] Step 8: Commit the native-core refresh-model change

```bash
git add native/nexa_http_native_core/src/runtime/client_registry.rs \
  native/nexa_http_native_core/src/runtime/executor.rs \
  native/nexa_http_native_core/tests/runtime_smoke.rs
git commit -m "refactor(nexa_http): switch proxy refresh to generation checks"
```

### Task 3: Add platform-owned runtime state implementations

**Files:**
- Modify: `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/lib.rs`
- Modify: `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs`
- Modify: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs`
- Modify: `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/lib.rs`
- Test: `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/tests/proxy_settings.rs`
- Test: `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/tests/proxy_settings.rs`
- Test: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/tests/proxy_settings.rs`
- Test: `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/tests/proxy_settings.rs`

- [ ] Step 1: Write one failing per-platform state test for snapshot + generation behavior

For each supported platform runtime, add or extend tests so they can verify:
- initial state starts with generation `0`
- updating the snapshot increments generation
- reading current snapshot returns the newest value

Use internal test-only helpers if needed.

- [ ] Step 2: Run the per-platform proxy tests to verify the new state behavior is missing

Run:
- `cargo test --manifest-path packages/nexa_http_native_android/native/nexa_http_native_android_ffi/Cargo.toml`
- `cargo test --manifest-path packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/Cargo.toml`
- `cargo test --manifest-path packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml`
- `cargo test --manifest-path packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/Cargo.toml`

Expected: FAIL for the new generation assertions

- [ ] Step 3: Add a shared per-runtime state holder in each platform runtime

In each platform `src/lib.rs`, introduce a focused state type with:

```rust
struct ProxyRuntimeState {
    generation: AtomicU64,
    snapshot: RwLock<ProxySettings>,
}
```

Add methods to:
- create from the initial discovered snapshot
- read the current snapshot
- read the current generation
- update the snapshot and increment generation when a real change occurs

- [ ] Step 4: Make each platform runtime implement the new `PlatformRuntimeState` contract

Replace direct `proxy_settings()` implementations with:
- `current_proxy_snapshot()`
- `proxy_generation()`

Wire `NexaHttpRuntime::new(...)` to receive the platform runtime state object.

- [ ] Step 5: Keep phase-1 behavior simple by initializing state once and exposing update helpers

Do not add true OS event listeners yet.
Instead:
- initialize state from the current platform snapshot at runtime creation
- leave a clear internal seam where platform listeners will call `update_snapshot(...)` in phase 2

- [ ] Step 6: Re-run the per-platform proxy tests to verify they pass

Run the same four cargo test commands from Step 2.
Expected: PASS

- [ ] Step 7: Commit the platform runtime state wiring

```bash
git add packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/lib.rs \
  packages/nexa_http_native_android/native/nexa_http_native_android_ffi/tests/proxy_settings.rs \
  packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs \
  packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/tests/proxy_settings.rs \
  packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs \
  packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/tests/proxy_settings.rs \
  packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/lib.rs \
  packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/tests/proxy_settings.rs
git commit -m "refactor(nexa_http): add per-platform proxy runtime state"
```

### Task 4: Remove obsolete probe semantics from tests and docs

**Files:**
- Modify: `docs/superpowers/specs/2026-03-29-proxy-runtime-state-design.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Test: `native/nexa_http_native_core/tests/proxy_runtime.rs`

- [ ] Step 1: Update any remaining tests or assertions that mention refresh probes

Search for:
- `refresh_probe`
- `next_refresh_probe_at`
- `refresh_failure_backoff`

Remove or rewrite those expectations so they describe generation-driven refresh behavior instead.

- [ ] Step 2: Update docs that mention proxy refresh mechanics

In `README.md` and `README.zh-CN.md`, keep the docs short:
- proxy state is platform-owned
- proxy refresh is generation-driven
- `native core` no longer polls for proxy drift

- [ ] Step 3: Re-run the full Rust workspace test suite

Run: `cargo test --workspace`
Expected: PASS

- [ ] Step 4: Commit the cleanup pass

```bash
git add docs/superpowers/specs/2026-03-29-proxy-runtime-state-design.md \
  README.md README.zh-CN.md \
  native/nexa_http_native_core/tests/proxy_runtime.rs \
  native/nexa_http_native_core/src/runtime/executor.rs
git commit -m "docs(nexa_http): align proxy refresh docs with runtime state model"
```

### Task 5: Final workspace verification

**Files:**
- Verify only

- [ ] Step 1: Run root workspace analysis

Run: `fvm dart run scripts/workspace_tools.dart analyze`
Expected: PASS

- [ ] Step 2: Run package Dart tests

Run: `cd packages/nexa_http && fvm dart test`
Expected: PASS

- [ ] Step 3: Run example Flutter tests

Run: `cd packages/nexa_http/example && env PUB_HOSTED_URL=https://pub.dev FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com fvm flutter test`
Expected: PASS

- [ ] Step 4: Run the Rust workspace tests again

Run: `cargo test --workspace`
Expected: PASS

- [ ] Step 5: Inspect final workspace state

Run:
- `git status --short`
- `rg -n "refresh_probe|next_refresh_probe_at|refresh_failure_backoff" native/nexa_http_native_core`

Expected:
- only intentional files changed
- no obsolete probe symbols left in active code

- [ ] Step 6: Commit the final verified result

```bash
git add .
git commit -m "refactor(nexa_http): move proxy refresh into platform runtime state"
```
