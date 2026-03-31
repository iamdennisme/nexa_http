# Nexa HTTP OkHttp API Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current public lifecycle-heavy API with an OkHttp-aligned HTTP API, move initialization fully behind internal lazy execution, and split end-user API from carrier-package SPI.

**Architecture:** The root `package:nexa_http/nexa_http.dart` library becomes a pure HTTP API surface built around `NexaHttpClient -> Call -> Request/Response`. Internal engine, worker, FFI, and platform runtime layers remain, but they are demoted behind lazy execution boundaries. Carrier packages switch from the root API to a dedicated platform SPI library so runtime bootstrap no longer pollutes the end-user model.

**Tech Stack:** Dart, Flutter federated plugins, isolates, FFI, Rust native transport, workspace scripts, bilingual README docs

---

### Task 1: Freeze the new end-user boundary and add a platform SPI library

**Files:**
- Create: `packages/nexa_http/lib/nexa_http_platform.dart`
- Modify: `packages/nexa_http/lib/nexa_http.dart`
- Modify: `packages/nexa_http/lib/nexa_http_native_runtime.dart`
- Modify: `packages/nexa_http/lib/src/api/api.dart`
- Modify: `packages/nexa_http/test/nexa_http_api_export_test.dart`
- Modify: `packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart`
- Modify: `packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart`
- Modify: `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart`
- Modify: `packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart`
- Modify: `packages/nexa_http_native_android/test/nexa_http_native_android_plugin_test.dart`
- Modify: `packages/nexa_http_native_ios/test/nexa_http_native_ios_plugin_test.dart`
- Modify: `packages/nexa_http_native_macos/test/nexa_http_native_macos_plugin_test.dart`
- Modify: `packages/nexa_http_native_windows/test/nexa_http_native_windows_plugin_test.dart`

- [ ] **Step 1: Write failing export tests for the new boundary**

Update `packages/nexa_http/test/nexa_http_api_export_test.dart` so it asserts:
- root exports the OkHttp-aligned public HTTP types
- root does not require `warmUp()` / `shutdown()` usage in examples
- platform runtime APIs are reachable through `package:nexa_http/nexa_http_platform.dart`, not the root usage docs

- [ ] **Step 2: Run the export-focused tests and confirm they fail against the current root API**

Run: `cd packages/nexa_http && fvm dart test test/nexa_http_api_export_test.dart`

- [ ] **Step 3: Add `nexa_http_platform.dart` as the carrier-package SPI entrypoint**

Expose only the runtime integration SPI needed by carrier packages:
- `NexaHttpNativeRuntime`
- `registerNexaHttpNativeRuntime(...)`
- optional registration visibility helpers if still required by carrier tests

- [ ] **Step 4: Remove runtime lifecycle concepts from the root library exports**

Update `packages/nexa_http/lib/nexa_http.dart` so it only exports end-user HTTP types and no longer advertises lifecycle or runtime-registration APIs.

- [ ] **Step 5: Move carrier packages to the SPI library**

Replace `package:nexa_http/nexa_http_native_runtime.dart` imports in each
carrier plugin with `package:nexa_http/nexa_http_platform.dart`.

- [ ] **Step 6: Re-run focused package and carrier tests**

Run:
- `cd packages/nexa_http && fvm dart test test/nexa_http_api_export_test.dart`
- `cd packages/nexa_http_native_android && fvm dart test`
- `cd packages/nexa_http_native_ios && fvm dart test`
- `cd packages/nexa_http_native_macos && fvm dart test`
- `cd packages/nexa_http_native_windows && fvm dart test`

- [ ] **Step 7: Commit the boundary freeze**

```bash
git add packages/nexa_http/lib/nexa_http.dart packages/nexa_http/lib/nexa_http_platform.dart packages/nexa_http/lib/nexa_http_native_runtime.dart packages/nexa_http/lib/src/api/api.dart packages/nexa_http/test/nexa_http_api_export_test.dart packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart packages/nexa_http_native_android/test/nexa_http_native_android_plugin_test.dart packages/nexa_http_native_ios/test/nexa_http_native_ios_plugin_test.dart packages/nexa_http_native_macos/test/nexa_http_native_macos_plugin_test.dart packages/nexa_http_native_windows/test/nexa_http_native_windows_plugin_test.dart
git commit -m "refactor(nexa_http): split end-user api from platform spi"
```

### Task 2: Introduce the OkHttp-aligned public HTTP types

**Files:**
- Create: `packages/nexa_http/lib/src/api/headers.dart`
- Create: `packages/nexa_http/lib/src/api/media_type.dart`
- Create: `packages/nexa_http/lib/src/api/request_body.dart`
- Create: `packages/nexa_http/lib/src/api/request.dart`
- Create: `packages/nexa_http/lib/src/api/request_builder.dart`
- Create: `packages/nexa_http/lib/src/api/response_body.dart`
- Create: `packages/nexa_http/lib/src/api/response.dart`
- Create: `packages/nexa_http/lib/src/api/call.dart`
- Create: `packages/nexa_http/lib/src/api/callback.dart`
- Create: `packages/nexa_http/lib/src/api/nexa_http_client_builder.dart`
- Modify: `packages/nexa_http/lib/src/api/api.dart`
- Modify: `packages/nexa_http/test/nexa_http_request_test.dart`
- Create: `packages/nexa_http/test/request_builder_test.dart`
- Create: `packages/nexa_http/test/response_body_test.dart`

- [ ] **Step 1: Write failing public API tests for request building and response body behavior**

Add tests that express the intended API:
- `RequestBuilder().url(...).get().build()`
- `RequestBuilder().url(...).post(RequestBody.bytes(...)).build()`
- `ResponseBody.bytes()/string()/byteStream()/close()`

- [ ] **Step 2: Run the new public API tests and confirm the types do not exist yet**

Run:
- `cd packages/nexa_http && fvm dart test test/request_builder_test.dart`
- `cd packages/nexa_http && fvm dart test test/response_body_test.dart`

- [ ] **Step 3: Add the public HTTP value types**

Implement:
- immutable `Headers`
- immutable `MediaType`
- immutable `Request`
- fluent `RequestBuilder`
- `RequestBody`
- immutable `Response`
- closable `ResponseBody`
- `Call` interface
- optional `Callback` interface
- `NexaHttpClientBuilder`

- [ ] **Step 4: Update `api.dart` exports to the new public model**

Ensure the root HTTP library exports the new types and stops centering the old
`NexaHttpRequest/NexaHttpResponse/NexaHttpMethod/NexaHttpClientConfig` model.

- [ ] **Step 5: Re-run the request/body tests until they pass**

Run:
- `cd packages/nexa_http && fvm dart test test/request_builder_test.dart`
- `cd packages/nexa_http && fvm dart test test/response_body_test.dart`

- [ ] **Step 6: Commit the public type layer**

```bash
git add packages/nexa_http/lib/src/api packages/nexa_http/test/nexa_http_request_test.dart packages/nexa_http/test/request_builder_test.dart packages/nexa_http/test/response_body_test.dart
git commit -m "feat(nexa_http): add okhttp-style public http types"
```

### Task 3: Refactor `NexaHttpClient` into a lightweight client plus `Call`

**Files:**
- Modify: `packages/nexa_http/lib/src/nexa_http_client.dart`
- Create: `packages/nexa_http/lib/src/client/real_nexa_http_client.dart`
- Create: `packages/nexa_http/lib/src/client/real_call.dart`
- Modify: `packages/nexa_http/test/nexa_http_client_test.dart`
- Create: `packages/nexa_http/test/call_api_test.dart`

- [ ] **Step 1: Write failing client/call tests for `newCall()` and `execute()`**

Cover:
- `NexaHttpClient()` is constructible without async initialization
- `client.newCall(request)` returns a call
- `call.execute()` produces a response
- `call.clone()` preserves request semantics
- `cancel()` transitions call state correctly even if cancellation is initially best-effort

- [ ] **Step 2: Run the client/call tests and confirm the old `open()/execute(request)` shape fails them**

Run:
- `cd packages/nexa_http && fvm dart test test/nexa_http_client_test.dart`
- `cd packages/nexa_http && fvm dart test test/call_api_test.dart`

- [ ] **Step 3: Implement the lightweight public client**

Update `packages/nexa_http/lib/src/nexa_http_client.dart` so it only holds:
- defaults/builder output
- a shared engine reference
- `newCall(Request request)`

Do not initialize worker/native resources in the constructor.

- [ ] **Step 4: Implement `RealCall` and route `execute()` through the engine interface**

Add `RealCall` in `packages/nexa_http/lib/src/client/real_call.dart`.

- [ ] **Step 5: Keep temporary internal adapters only as needed**

If the old request/response DTO path is still needed during migration, keep it
behind the engine boundary only. Do not leak it through the public client API.

- [ ] **Step 6: Re-run focused client/call tests until green**

Run:
- `cd packages/nexa_http && fvm dart test test/nexa_http_client_test.dart`
- `cd packages/nexa_http && fvm dart test test/call_api_test.dart`

- [ ] **Step 7: Commit the client/call refactor**

```bash
git add packages/nexa_http/lib/src/nexa_http_client.dart packages/nexa_http/lib/src/client packages/nexa_http/test/nexa_http_client_test.dart packages/nexa_http/test/call_api_test.dart
git commit -m "refactor(nexa_http): align client and call api with okhttp"
```

### Task 4: Add an internal engine layer and move lazy initialization behind execution

**Files:**
- Create: `packages/nexa_http/lib/src/internal/engine/nexa_http_engine.dart`
- Create: `packages/nexa_http/lib/src/internal/engine/nexa_http_engine_manager.dart`
- Create: `packages/nexa_http/lib/src/internal/engine/engine_request.dart`
- Create: `packages/nexa_http/lib/src/internal/engine/engine_response.dart`
- Create: `packages/nexa_http/lib/src/internal/engine/client_pool.dart`
- Create: `packages/nexa_http/lib/src/internal/engine/client_key.dart`
- Modify: `packages/nexa_http/lib/src/client/real_call.dart`
- Modify: `packages/nexa_http/test/nexa_http_client_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_native_integration_test.dart`
- Create: `packages/nexa_http/test/internal_engine_test.dart`

- [ ] **Step 1: Write failing internal engine tests for lazy one-time initialization**

Cover:
- constructing the client does not initialize the engine
- first `execute()` initializes the engine
- later calls reuse initialized resources
- same-config client defaults reuse pooled native clients internally

- [ ] **Step 2: Run the focused engine tests and confirm the initialization still lives in the wrong place**

Run:
- `cd packages/nexa_http && fvm dart test test/internal_engine_test.dart`

- [ ] **Step 3: Introduce the engine manager abstraction**

Move all “ensure worker/runtime/native client” orchestration into
`src/internal/engine/*`.

- [ ] **Step 4: Make `RealCall.execute()` the only end-user trigger for initialization**

The engine must:
- ensure worker availability
- ensure FFI data source availability
- ensure pooled native client availability
- map internal results back to public `Response`

- [ ] **Step 5: Re-run engine and public integration tests**

Run:
- `cd packages/nexa_http && fvm dart test test/internal_engine_test.dart`
- `cd packages/nexa_http && fvm dart test test/nexa_http_native_integration_test.dart`

- [ ] **Step 6: Commit the engine layer**

```bash
git add packages/nexa_http/lib/src/internal/engine packages/nexa_http/lib/src/client/real_call.dart packages/nexa_http/test/internal_engine_test.dart packages/nexa_http/test/nexa_http_native_integration_test.dart
git commit -m "refactor(nexa_http): move lazy init into internal engine"
```

### Task 5: Demote worker, FFI, and platform runtime code behind internal boundaries

**Files:**
- Move/Create: `packages/nexa_http/lib/src/internal/worker/*`
- Move/Create: `packages/nexa_http/lib/src/internal/ffi/*`
- Move/Create: `packages/nexa_http/lib/src/internal/platform/*`
- Modify: `packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart`
- Modify: `packages/nexa_http/lib/src/data/sources/*`
- Modify: `packages/nexa_http/test/nexa_http_worker_proxy_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_native_library_loader_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_native_data_source_factory_test.dart`
- Modify: `packages/nexa_http/test/support/register_host_native_runtime.dart`

- [ ] **Step 1: Write failing tests that enforce the new boundary**

Add or update tests so:
- public tests stop importing `package:nexa_http/src/worker/*`
- internal tests own worker/runtime assertions
- carrier packages use only `package:nexa_http/nexa_http_platform.dart`

- [ ] **Step 2: Move worker files under `src/internal/worker` and repair imports**

Do not change behavior yet; only change location and visibility expectations.

- [ ] **Step 3: Re-home loader/runtime files under `src/internal/platform`**

Keep the same resolution behavior while narrowing who can import the files.

- [ ] **Step 4: Re-home FFI bridge files under `src/internal/ffi` where practical**

Preserve ABI behavior and body ownership semantics.

- [ ] **Step 5: Re-run focused internal tests**

Run:
- `cd packages/nexa_http && fvm dart test test/nexa_http_worker_proxy_test.dart`
- `cd packages/nexa_http && fvm dart test test/nexa_http_native_library_loader_test.dart`
- `cd packages/nexa_http && fvm dart test test/nexa_http_native_data_source_factory_test.dart`

- [ ] **Step 6: Commit the internal boundary cleanup**

```bash
git add packages/nexa_http/lib/src/internal packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart packages/nexa_http/lib/src/data/sources packages/nexa_http/test/nexa_http_worker_proxy_test.dart packages/nexa_http/test/nexa_http_native_library_loader_test.dart packages/nexa_http/test/nexa_http_native_data_source_factory_test.dart packages/nexa_http/test/support/register_host_native_runtime.dart
git commit -m "refactor(nexa_http): demote transport runtime behind internal boundaries"
```

### Task 6: Remove the public lifecycle-heavy API and obsolete startup workarounds

**Files:**
- Modify: `packages/nexa_http/lib/nexa_http.dart`
- Delete/Rewrite: `packages/nexa_http/example/lib/src/nexa_http_client_initializer.dart`
- Modify: `packages/nexa_http/example/lib/main.dart`
- Modify: `packages/nexa_http/example/lib/src/image_perf/nexa_http_image_file_service.dart`
- Modify: `packages/nexa_http/example/test/nexa_http_client_initializer_test.dart`
- Modify: `packages/nexa_http/example/test/nexa_http_image_file_service_test.dart`
- Modify: `packages/nexa_http/example/test/widget_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_client_test.dart`

- [ ] **Step 1: Write failing example and package tests that use only the new OkHttp-style API**

Cover:
- example creates `NexaHttpClient` directly
- example builds `Request` and executes `Call`
- image transport uses the client/call API without worker imports
- no test calls `warmUp()/shutdown()/open(...)`

- [ ] **Step 2: Run the focused example tests and confirm they still encode old startup assumptions**

Run:
- `cd packages/nexa_http/example && fvm flutter test test/widget_test.dart`
- `cd packages/nexa_http/example && fvm flutter test test/nexa_http_image_file_service_test.dart`

- [ ] **Step 3: Delete `NexaHttp.warmUp()/shutdown()` from the root API**

The root end-user library should no longer expose lifecycle controls.

- [ ] **Step 4: Remove `NexaHttpClient.open(...)` and rewrite example code to standard usage**

Delete the example initializer helper if it no longer adds value after the API
cleanup.

- [ ] **Step 5: Re-run package and example tests**

Run:
- `cd packages/nexa_http && fvm dart test test/nexa_http_client_test.dart`
- `cd packages/nexa_http/example && fvm flutter test`

- [ ] **Step 6: Commit the lifecycle cleanup**

```bash
git add packages/nexa_http/lib/nexa_http.dart packages/nexa_http/lib/src/nexa_http_client.dart packages/nexa_http/example/lib/main.dart packages/nexa_http/example/lib/src/image_perf/nexa_http_image_file_service.dart packages/nexa_http/example/test/nexa_http_client_initializer_test.dart packages/nexa_http/example/test/nexa_http_image_file_service_test.dart packages/nexa_http/example/test/widget_test.dart
git commit -m "refactor(nexa_http): remove public startup lifecycle api"
```

### Task 7: Rewrite docs and examples to one model only

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`
- Modify: `packages/nexa_http/example/README.md`

- [ ] **Step 1: Update root docs to the OkHttp-style API**

Document:
- `NexaHttpClient`
- `RequestBuilder`
- `newCall().execute()`
- no manual prewarm or shutdown

- [ ] **Step 2: Delete outdated startup guidance from package and example READMEs**

Remove:
- synchronous constructor guidance
- first-frame deferral guidance
- timing breakdown language tied to workaround initialization flows

- [ ] **Step 3: Add one consistent example snippet across English and Chinese docs**

Use the same API story in all READMEs.

- [ ] **Step 4: Run documentation spot checks**

Run:
- `rg "warmUp\\(|shutdown\\(|open\\(|NexaHttpClient\\(" README.md README.zh-CN.md packages/nexa_http/README.md packages/nexa_http/example/README.md`

- [ ] **Step 5: Commit the doc cleanup**

```bash
git add README.md README.zh-CN.md packages/nexa_http/README.md packages/nexa_http/example/README.md
git commit -m "docs(readme): align public api docs with okhttp model"
```

### Task 8: Run full verification and final cleanup

**Files:**
- Verify only

- [ ] **Step 1: Run package analysis**

Run: `cd packages/nexa_http && fvm dart analyze`

- [ ] **Step 2: Run package tests**

Run: `cd packages/nexa_http && fvm dart test`

- [ ] **Step 3: Run example tests**

Run: `cd packages/nexa_http/example && fvm flutter test`

- [ ] **Step 4: Run carrier package tests**

Run:
- `cd packages/nexa_http_native_android && fvm dart test`
- `cd packages/nexa_http_native_ios && fvm dart test`
- `cd packages/nexa_http_native_macos && fvm dart test`
- `cd packages/nexa_http_native_windows && fvm dart test`

- [ ] **Step 5: Run workspace analysis**

Run: `fvm dart run scripts/workspace_tools.dart analyze`

- [ ] **Step 6: Run workspace tests**

Run: `fvm dart run scripts/workspace_tools.dart test`

- [ ] **Step 7: Run Rust tests**

Run: `cargo test --workspace`

- [ ] **Step 8: Inspect final diff scope**

Run: `git diff --stat`

- [ ] **Step 9: Commit the integrated result**

```bash
git add .
git commit -m "feat(nexa_http): align public api with okhttp"
```
