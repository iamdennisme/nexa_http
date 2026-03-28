# Nexa HTTP Streaming Response Design

## Status

Approved in chat on 2026-03-28.

## Context

The transport hot-path work for sub-project `A` is complete and has already
improved the Android 60-image benchmark materially. The remaining performance
gap is in the download-to-cache pipeline:

- the example image path still waits for a full response body before returning a
  `FileServiceResponse`
- both the `default_http` example path and the `nexa_http` example path still
  buffer whole bodies in memory and then expose them as
  `Stream.value(bodyBytes)`
- `flutter_cache_manager` itself can already write true response streams to disk
  incrementally, but the current integration does not let it do so

The current `nexa_http` public API is also still buffered-first:

- `HttpExecutor.execute(...)` returns a full `NexaHttpResponse`
- response consumers read `bodyBytes` or `bodyText`
- the FFI contract returns response metadata plus a full body buffer

That design is now the bottleneck for larger payloads, higher concurrency, and
reuse in other projects.

The user explicitly wants:

- one primary request API, not parallel buffered and streaming client APIs
- no compatibility layer left behind in the final design
- a solution that works for the example app and for other projects

## Goals

- Make `execute()` stream-first across the public `nexa_http` API
- Expose exactly two body consumption modes:
  - streaming bytes
  - fully aggregated bytes
- Remove buffered-first response semantics from the public transport API
- Replace the current one-shot FFI response body contract with a streaming body
  protocol
- Let the example image cache pipeline hand real response streams directly to
  `flutter_cache_manager`
- Keep the network layer content-agnostic: bytes only, no text/json helpers in
  the transport API

## Non-Goals

- Preserving the current `NexaHttpResponse` buffered public contract
- Preserving the current `HttpExecutor.execute(...) -> Future<NexaHttpResponse>`
  signature
- Introducing format-aware helpers such as `readJson()` or `readText()` in the
  transport layer
- Designing image resize, crop, or transform operations
- Solving CDN/server-side image resizing
- Keeping backward-compatible shims for older callers

## Product Decision

This is a deliberate breaking change.

The public API will become stream-first:

- `execute()` remains the single request entrypoint
- `execute()` returns `NexaHttpStreamedResponse`
- callers choose either:
  - `bodyStream`
  - `readBytes()`

The old buffered-first response model is not preserved as public compatibility
surface.

## Design Principles

- One request API, one response model
- Network layer deals in bytes, not content semantics
- Streaming should be the native path, not a compatibility wrapper
- Aggregation should be explicit and opt-in
- FFI stream control must be deterministic and easy to cancel
- Example-specific file caching should be built on top of the generic streaming
  transport API, not beside it

## Public API Shape

### Request side

`NexaHttpRequest` remains the public request type. No file-type-specific request
surface is introduced.

### Response side

The public response type becomes `NexaHttpStreamedResponse`.

Proposed shape:

```dart
final class NexaHttpStreamedResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Uri? finalUri;
  final int? contentLength;
  final Stream<Uint8List> bodyStream;

  Future<Uint8List> readBytes();
}
```

Rules:

- `bodyStream` and `readBytes()` are mutually exclusive
- the body is single-consumption
- metadata (`statusCode`, `headers`, `finalUri`, `contentLength`) is readable at
  any time
- text and JSON decoding are caller responsibilities

Second-consumption behavior is explicit:

- once `readBytes()` has been called, any later listen on `bodyStream` throws
  `StateError`
- once `readBytes()` has been called, any later call to `readBytes()` throws
  `StateError`
- once `bodyStream` has been listened to, any later call to `readBytes()`
  throws `StateError`
- once `bodyStream` has been listened to, any later second listen on
  `bodyStream` throws `StateError`
- the thrown message must clearly state that the response body has already been
  consumed

### Executor side

`HttpExecutor` and `NexaHttpClient` become stream-first:

```dart
abstract interface class HttpExecutor {
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request);
  Future<void> close();
}
```

This keeps one entrypoint and avoids parallel buffered/streaming client APIs.

Close semantics are explicit:

- if `close()` is called while `execute()` is still waiting for a response head,
  that `execute()` future fails with `NexaHttpException(code: 'client_closed')`
- `close()` cancels all active streamed responses created by that executor
- active `bodyStream` instances emit `NexaHttpException(code: 'client_closed')`
- in-flight `readBytes()` futures fail with the same exception
- after `close()`, the executor rejects any new request

## Repository Areas

### Public Dart API

- `packages/nexa_http/lib/src/api/http_executor.dart`
- `packages/nexa_http/lib/src/api/nexa_http_request.dart`
- `packages/nexa_http/lib/src/api/nexa_http_streamed_response.dart`
- `packages/nexa_http/lib/src/api/api.dart`
- `packages/nexa_http/lib/src/nexa_http_client.dart`

Responsibilities:

- expose the new stream-first response type
- remove buffered-first response semantics from the primary transport API
- provide explicit `readBytes()` aggregation on the streamed response

### FFI and native data source

- `native/nexa_http_native_core/include/nexa_http_native.h`
- `native/nexa_http_native_core/src/api/ffi.rs`
- `native/nexa_http_native_core/src/runtime/executor.rs`
- `packages/nexa_http/lib/nexa_http_bindings_generated.dart`
- `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`

Responsibilities:

- replace one-shot full-body response returns with a stream handle protocol
- expose streamed response heads and chunk pulls
- support cancel and close semantics

### Platform wrappers

- `packages/nexa_http_native_android/native/*/src/lib.rs`
- `packages/nexa_http_native_ios/native/*/src/lib.rs`
- `packages/nexa_http_native_linux/native/*/src/lib.rs`
- `packages/nexa_http_native_macos/native/*/src/lib.rs`
- `packages/nexa_http_native_windows/native/*/src/lib.rs`

Responsibilities:

- adopt the new streaming FFI symbols uniformly

### Integrations and consumers

- `packages/nexa_http/lib/src/integrations/dio/nexa_http_dio_adapter.dart`
- `packages/nexa_http/example/lib/src/image_perf/nexa_http_image_file_service.dart`
- `packages/nexa_http/example/lib/src/image_perf/instrumented_http_file_service.dart`
- `packages/nexa_http/example/lib/src/image_perf/buffered_file_service_response.dart`

Responsibilities:

- adapt `Dio` to the stream-first transport API
- hand real response streams to `flutter_cache_manager`
- remove the fake streaming adapter that wraps an already buffered body

## FFI Streaming Protocol

## Execute

The native request entrypoint becomes stream-first:

- `nexa_http_client_execute_stream(...)`

It returns response metadata plus a stream handle:

```c
typedef struct NexaHttpStreamedResponseHead {
  uint8_t is_success;
  uint16_t status_code;
  NexaHttpHeaderEntry* headers_ptr;
  uintptr_t headers_len;
  char* final_url_ptr;
  uintptr_t final_url_len;
  uint64_t stream_id;
  uint64_t content_length;
  uint8_t has_content_length;
  char* error_json;
} NexaHttpStreamedResponseHead;
```

This struct does not contain the body bytes.

Head result semantics are explicit:

- `is_success = 1` means `stream_id` and response metadata are valid and
  `error_json` must be `NULL`
- `is_success = 0` means the request failed before a response head was produced,
  `stream_id` is invalid, and `error_json` must be populated

## Pull chunks

Dart reads the body incrementally:

- `nexa_http_stream_next_chunk(stream_id)`

Returned result:

```c
typedef struct NexaHttpStreamChunkResult {
  uint8_t is_success;
  uint8_t is_done;
  uint8_t* chunk_ptr;
  uintptr_t chunk_len;
  char* error_json;
} NexaHttpStreamChunkResult;
```

Semantics:

- `is_success = 1` means the read operation itself succeeded and `error_json`
  must be `NULL`
- `is_success = 0` means the stream failed during body read and `error_json`
  must be populated
- `is_done = 1` means EOF and `chunk_len` must be `0`
- `chunk_len > 0` means a chunk is available and `is_done` must be `0`

Chunk size is runtime-controlled, not caller-controlled:

- the first implementation uses a fixed internal chunk size
- recommended initial size: `64 KiB`
- chunk size is not part of the public Dart API

## Cancel and close

The protocol also includes:

- `nexa_http_stream_cancel(stream_id)`
- `nexa_http_stream_close(stream_id)`
- `nexa_http_stream_chunk_result_free(...)`
- `nexa_http_streamed_response_head_free(...)`

`cancel` is used when Dart stops early.

`close` is a deterministic cleanup path after normal completion.

Error propagation is explicit:

- if native execution fails before a response head is produced, `execute()`
  throws `NexaHttpException`
- if the response head is produced successfully but body streaming later fails,
  `bodyStream` emits an error event with `NexaHttpException`
- `readBytes()` fails with the same `NexaHttpException`
- after a mid-stream failure, stream cleanup is automatic; callers do not need
  to call `close()` manually

## Why pull, not push

The design chooses a pull-based stream over repeated native-to-Dart callbacks:

- Dart `StreamController` wrapping is simpler
- cancel semantics are explicit
- backpressure is more natural
- Android callback/trampoline complexity stays lower
- native lifetime management is easier to reason about

## Rust Runtime Design

Rust maintains a stream registry:

- `stream_id -> active body stream state`

Each active entry owns:

- response body stream
- closed/cancelled state
- any needed synchronization for `next_chunk`, `cancel`, and `close`

## Dart Data Source Design

The FFI data source:

1. executes the request and receives a response head
2. constructs `bodyStream` around repeated `stream_next_chunk(...)` calls
3. calls `stream_close(...)` on normal completion
4. calls `stream_cancel(...)` if the stream is abandoned early

`readBytes()` is implemented by aggregating `bodyStream` once.

No parallel buffered-native transport path remains.

## Example Image Pipeline Design

The example `nexa_http` image file service will:

- use `execute()` to get `NexaHttpStreamedResponse`
- preserve the current scheduling priorities from sub-project `A`
- return a true `FileServiceResponse` whose `content` is the native HTTP body
  stream

That means `flutter_cache_manager` can consume the stream via its existing
`pipe(sink)` logic instead of receiving `Stream.value(fullBodyBytes)`.

The current fake-stream adapter in:

- `packages/nexa_http/example/lib/src/image_perf/buffered_file_service_response.dart`

is no longer the `nexa_http` path.

## Dio Integration Design

The `Dio` adapter is rewritten on top of the stream-first response model.

Behavior:

- `ResponseType.stream` bridges `bodyStream` directly
- `ResponseType.bytes` aggregates via `readBytes()`
- text/json handling remains a `Dio` concern, not a `nexa_http` transport
  concern

## Migration Impact

Existing callers will need to change from:

```dart
final response = await client.execute(request);
final bytes = response.bodyBytes;
```

to:

```dart
final response = await client.execute(request);
final bytes = await response.readBytes();
```

Text and JSON callers will aggregate bytes first and decode themselves.

This is intentional.

## Testing Strategy

### Rust

- stream registry lifecycle tests
- chunk iteration tests
- cancel/close tests
- EOF and error propagation tests
- concurrency tests for stream handle safety

### Dart

- streamed response single-consumption tests
- `readBytes()` aggregation tests
- early cancel tests
- FFI chunk free/close correctness tests

### Dio

- `ResponseType.stream` direct bridge tests
- `ResponseType.bytes` aggregation tests
- timeout and cancel tests

### Example

- `flutter_cache_manager` integration tests with true stream-backed
  `FileServiceResponse`
- image scheduling tests remain green
- Android benchmark still succeeds for `default_http` and `nexa_http`

## Acceptance Criteria

- `HttpExecutor.execute(...)` returns `NexaHttpStreamedResponse`
- `NexaHttpStreamedResponse` exposes only:
  - metadata
  - `bodyStream`
  - `readBytes()`
- no buffered-first compatibility client API remains
- `nexa_http` example image path no longer buffers the full response body before
  returning `FileServiceResponse`
- `packages/nexa_http` tests pass
- `packages/nexa_http/example` tests pass
- Android emulator benchmark still succeeds for both transport modes

## Risks

- this is a breaking public API change
- `Dio` adapter rewrite can surface subtle stream/timeout differences
- stream handle leaks are easier to introduce than one-shot response leaks
- cancellation semantics must be deterministic
- consumers may accidentally try to consume the body twice unless the API fails
  loudly and predictably
