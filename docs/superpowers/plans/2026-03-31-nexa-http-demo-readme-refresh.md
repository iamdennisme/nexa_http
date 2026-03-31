# Nexa HTTP Demo and README Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old example narrative with an HTTP Playground plus A/B benchmark, and rewrite the English/Chinese README set so it matches the OkHttp-style public API.

**Architecture:** The example app will be split into two focused surfaces: a playground page that demonstrates the public request/call API, and a benchmark page that runs sequential A/B concurrency tests for `nexa_http` and Dart `HttpClient`. README files will be rewritten around that same public-facing story and will stop centering old startup and image-cache behavior.

**Tech Stack:** Dart, Flutter, Cupertino widgets, `dart:io` `HttpClient`, `nexa_http`, fixture server, bilingual Markdown docs

---

### Task 1: Lock the new example scope with tests first

**Files:**
- Modify: `packages/nexa_http/example/test/widget_test.dart`
- Create: `packages/nexa_http/example/test/benchmark_runner_test.dart`

- [ ] **Step 1: Write failing widget tests for the new app sections**
- [ ] **Step 2: Write failing benchmark tests for scenario planning and metric aggregation**
- [ ] **Step 3: Run focused example tests and confirm they fail against the current app**

### Task 2: Replace the old example implementation

**Files:**
- Modify: `packages/nexa_http/example/lib/main.dart`
- Create: `packages/nexa_http/example/lib/src/playground/http_playground_page.dart`
- Create: `packages/nexa_http/example/lib/src/benchmark/benchmark_models.dart`
- Create: `packages/nexa_http/example/lib/src/benchmark/benchmark_runner.dart`
- Create: `packages/nexa_http/example/lib/src/benchmark/benchmark_page.dart`
- Delete: `packages/nexa_http/example/lib/src/image_perf/*`

- [ ] **Step 1: Add the new app shell and segmented navigation**
- [ ] **Step 2: Implement the playground page around the public `nexa_http` API**
- [ ] **Step 3: Implement the benchmark runner, models, and UI**
- [ ] **Step 4: Remove the old image-performance implementation**
- [ ] **Step 5: Re-run example tests until they pass**

### Task 3: Clean up example dependencies and docs

**Files:**
- Modify: `packages/nexa_http/example/pubspec.yaml`
- Modify: `packages/nexa_http/example/README.md`

- [ ] **Step 1: Remove image-cache-specific example dependencies**
- [ ] **Step 2: Rewrite the example README around Playground + Benchmark**
- [ ] **Step 3: Run `flutter pub get` and example tests again**

### Task 4: Rewrite the workspace and package README set

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`

- [ ] **Step 1: Rewrite the root English README**
- [ ] **Step 2: Rewrite the root Chinese README**
- [ ] **Step 3: Rewrite the package README**
- [ ] **Step 4: Cross-check commands and API examples against the codebase**

### Task 5: Verify the final state

**Files:**
- Verify only

- [ ] **Step 1: Run focused example tests**
- [ ] **Step 2: Run example analysis**
- [ ] **Step 3: Run targeted package/workspace verification as needed**
- [ ] **Step 4: Review the diff for stale image-cache references**
