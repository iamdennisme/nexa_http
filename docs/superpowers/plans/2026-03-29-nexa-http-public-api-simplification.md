# Nexa HTTP Public API Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Dio integration from `nexa_http`, simplify the public API to `NexaHttpRequest + NexaHttpClient.execute`, and update docs/tests/examples to match.

**Architecture:** The public Dart package keeps the existing native transport path and request/response models, but removes the parallel Dio adapter surface and the `HttpExecutor` abstraction that only supported it. `NexaHttpRequest` becomes the only request-construction convenience layer, and its helpers are restricted to HTTP method semantics.

**Tech Stack:** Dart, Flutter, Freezed, FFI, Rust-backed native transport, repository workspace scripts

---

### Task 1: Remove Dio package surface

**Files:**
- Modify: `packages/nexa_http/pubspec.yaml`
- Delete: `packages/nexa_http/lib/nexa_http_dio.dart`
- Delete: `packages/nexa_http/lib/src/integrations/dio/nexa_http_dio_adapter.dart`
- Delete: `packages/nexa_http/test/nexa_http_dio_adapter_test.dart`
- Delete: `packages/nexa_http/test/nexa_http_dio_adapter_integration_test.dart`
- Delete: `packages/nexa_http/tool/benchmark_nexa_http_vs_dio.dart`

- [ ] **Step 1: Remove `dio` from the package manifest**
- [ ] **Step 2: Delete the public Dio entrypoint and adapter implementation**
- [ ] **Step 3: Delete Dio-specific tests and tooling**
- [ ] **Step 4: Run package-level analysis or targeted tests to catch stale imports**

### Task 2: Simplify the public API contracts

**Files:**
- Delete: `packages/nexa_http/lib/src/api/http_executor.dart`
- Modify: `packages/nexa_http/lib/src/api/api.dart`
- Modify: `packages/nexa_http/lib/src/nexa_http_client.dart`
- Modify: `packages/nexa_http/lib/src/api/nexa_http_request.dart`
- Modify: `packages/nexa_http/test/nexa_http_api_export_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_client_test.dart`
- Modify: `packages/nexa_http/test/nexa_http_native_integration_test.dart`

- [ ] **Step 1: Remove the `HttpExecutor` abstraction from exports and implementation**
- [ ] **Step 2: Update `NexaHttpClient` to stand on its own public API**
- [ ] **Step 3: Remove `NexaHttpRequest.text/json` and add method-aligned `post/put` helpers**
- [ ] **Step 4: Update tests to use the new request surface**
- [ ] **Step 5: Run focused package tests for request/client behavior**

### Task 3: Update example code to use direct request execution

**Files:**
- Modify: `packages/nexa_http/example/lib/src/image_perf/nexa_http_image_file_service.dart`
- Modify: `packages/nexa_http/example/test/nexa_http_image_file_service_test.dart`
- Delete: `packages/nexa_http/example/nexa_http_dio_consumer`

- [ ] **Step 1: Replace any `HttpExecutor` dependency in examples with direct `NexaHttpClient` usage or local fakes**
- [ ] **Step 2: Remove the Dio consumer example app entirely**
- [ ] **Step 3: Run example tests or targeted analysis to catch stale example references**

### Task 4: Update docs to the single-path API

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`

- [ ] **Step 1: Remove all Dio adapter examples and mentions**
- [ ] **Step 2: Rewrite usage snippets around `NexaHttpRequest + execute`**
- [ ] **Step 3: Remove deleted example references from test and development instructions**

### Task 5: Verify the workspace after the breaking API cleanup

**Files:**
- Verify only

- [ ] **Step 1: Run `dart test` in `packages/nexa_http`**
- [ ] **Step 2: Run `flutter test` in `packages/nexa_http/example` if dependencies allow**
- [ ] **Step 3: Run `dart run scripts/workspace_tools.dart analyze` or equivalent targeted analysis if needed**
- [ ] **Step 4: Inspect `git diff --stat` to confirm only intended files changed**
