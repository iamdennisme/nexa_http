# rust_net FFI Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current `rinf` transport with an async direct FFI bridge and benchmark it against direct `dio`.

**Architecture:** Dart sends request metadata plus raw body bytes to Rust through a new async FFI entrypoint. Rust executes requests on a shared Tokio runtime, returns `RustNetBinaryResult` through a callback, and Dart decodes the result without base64 payloads.

**Tech Stack:** Flutter, Dart FFI, reqwest, Tokio, freezed/json_serializable, fixture HTTP server.

---

### Task 1: Add failing Dart tests for raw body transport

**Files:**
- Modify: `packages/rust_net/test/rust_net_client_test.dart`
- Create: `packages/rust_net/test/native_http_request_mapper_test.dart`

- [ ] **Step 1: Write failing tests**
- [ ] **Step 2: Run tests to verify they fail for missing raw-body transport**
- [ ] **Step 3: Implement the minimal DTO and mapper changes**
- [ ] **Step 4: Run the tests to verify they pass**

### Task 2: Replace the Dart transport layer

**Files:**
- Modify: `packages/rust_net/lib/src/data/sources/ffi_rust_net_native_data_source.dart`
- Modify: `packages/rust_net/lib/rust_net_bindings_generated.dart`
- Delete: `packages/rust_net/lib/src/rinf/rust_net_rinf_runtime.dart`
- Modify: `packages/rust_net/src/rust_net.h`

- [ ] **Step 1: Write failing tests for binary-result decoding / async completion**
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement direct FFI callback transport**
- [ ] **Step 4: Run Dart tests**

### Task 3: Replace the Rust execution model

**Files:**
- Modify: `packages/rust_net/native/rust_net_native/src/lib.rs`
- Modify: `packages/rust_net/native/rust_net_native/Cargo.toml`

- [ ] **Step 1: Write failing Rust tests around async execution path if needed**
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement shared Tokio runtime, async reqwest client, and bounded inflight execution**
- [ ] **Step 4: Run Rust tests**

### Task 4: Add benchmark and demo

**Files:**
- Modify: `fixture_server/http_fixture/fixture_handler.dart`
- Create: `scripts/benchmark_rust_net_vs_dio.dart`
- Modify: `packages/rust_net/example/rust_net_dio_consumer/lib/main.dart`

- [ ] **Step 1: Add a local binary fixture endpoint**
- [ ] **Step 2: Add a benchmark script for direct `dio` vs `rust_net`**
- [ ] **Step 3: Add an example page to run the comparison interactively**
- [ ] **Step 4: Run the benchmark and record the command/output**
