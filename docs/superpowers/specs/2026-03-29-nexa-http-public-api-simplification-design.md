# Nexa HTTP Public API Simplification Design

## Status

Approved in chat on 2026-03-29.

## Context

The current `nexa_http` public package still exposes a Dio adapter and a mixed request-helper surface:

- `NexaHttpClient` executes requests through the native transport
- `NexaHttpDioAdapter` adds a second integration path
- `NexaHttpRequest.get` and `NexaHttpRequest.delete` describe HTTP methods
- `NexaHttpRequest.text` and `NexaHttpRequest.json` describe request-body encoding

That makes the public API larger than necessary and mixes two different concerns into one request model:

1. HTTP method selection
2. Request body encoding

The intended public integration path is simpler:

- business code constructs a `NexaHttpRequest`
- business code executes it through `NexaHttpClient.execute`

## Goals

- Remove Dio integration from the public package entirely
- Make `NexaHttpClient.execute(NexaHttpRequest request)` the only request execution path
- Keep `NexaHttpRequest` as the only public request-construction model
- Make `NexaHttpRequest` helpers align with HTTP method semantics
- Remove request helpers that encode body format rather than express HTTP method
- Update tests, docs, and examples to reflect the simplified API

## Non-Goals

- Refactoring the native Rust runtime, FFI ABI, or platform carrier packages
- Adding `client.get/post/put/delete` convenience methods
- Changing the wire format between Dart and Rust
- Redesigning response decoding or exception mapping

## Design Principles

- The public package should expose one clear way to send requests
- Request helpers should map cleanly to HTTP semantics
- Body encoding policy belongs to business code unless a helper clearly matches HTTP semantics
- Breaking changes should remove ambiguity rather than add parallel APIs

## Public API Design

### Kept

- `NexaHttpClient`
- `NexaHttpClientConfig`
- `NexaHttpRequest`
- `NexaHttpResponse`
- `NexaHttpException`
- `NexaHttpMethod`

### Removed

- `package:nexa_http/nexa_http_dio.dart`
- `NexaHttpDioAdapter`
- `dio` package dependency from `packages/nexa_http`
- Dio-related tests, examples, tooling, and docs

### Request Construction

`NexaHttpClient` remains responsible only for executing requests:

```dart
final client = NexaHttpClient(config: config);
final response = await client.execute(request);
```

`NexaHttpRequest` remains the public request model and keeps the generic constructor:

```dart
NexaHttpRequest(
  method: NexaHttpMethod.post,
  uri: Uri.parse('https://example.com/items'),
  headers: {'content-type': 'application/json'},
  bodyBytes: utf8.encode('{"name":"demo"}'),
  timeout: const Duration(seconds: 10),
)
```

`NexaHttpRequest` convenience factories should express HTTP methods only:

- `NexaHttpRequest.get`
- `NexaHttpRequest.post`
- `NexaHttpRequest.put`
- `NexaHttpRequest.delete`

These factories should keep a consistent parameter shape:

- `uri`
- `headers`
- `bodyBytes` where method semantics allow it
- `timeout`

`query` remains part of `Uri`, not a separate request field.

### Removed Request Helpers

The following helpers should be removed:

- `NexaHttpRequest.text`
- `NexaHttpRequest.json`

They are ambiguous because they describe request-body encoding rather than HTTP method. Business code should set `headers` and `bodyBytes` directly when needed.

## Interface Cleanup

`HttpExecutor` should be removed from the public package.

It currently exists as an extra abstraction layer above `NexaHttpClient`, but after removing Dio integration it no longer defines a meaningful parallel execution path for consumers. Public usage should depend on `NexaHttpClient` directly.

Internal tests and examples that currently depend on `HttpExecutor` should be updated to use small `NexaHttpClient`-compatible fakes or direct request handling abstractions local to the test.

## Documentation and Example Changes

The docs should only show one public usage pattern:

1. create a `NexaHttpClient`
2. build a `NexaHttpRequest`
3. call `execute`

The following content should be removed:

- all Dio adapter examples in root and package READMEs
- the `nexa_http_dio_consumer` example app
- Dio benchmark tooling tied to the removed adapter

Examples that still demonstrate direct request execution should be kept.

## Testing Strategy

Keep:

- request mapping tests
- FFI data source tests
- native integration tests
- client behavior tests
- package export tests updated for the smaller API

Remove:

- Dio adapter unit tests
- Dio adapter integration tests
- tests whose only purpose is validating the removed public entrypoint

Add or update:

- request factory tests for new `post` and `put` helpers if current coverage is insufficient
- export assertions showing Dio APIs are gone and the core request/response/client APIs remain

## Impacted Files

Expected changes include:

- `packages/nexa_http/pubspec.yaml`
- `packages/nexa_http/lib/nexa_http.dart`
- `packages/nexa_http/lib/nexa_http_dio.dart`
- `packages/nexa_http/lib/src/api/http_executor.dart`
- `packages/nexa_http/lib/src/api/nexa_http_request.dart`
- `packages/nexa_http/lib/src/integrations/dio/nexa_http_dio_adapter.dart`
- `packages/nexa_http/lib/src/nexa_http_client.dart`
- `packages/nexa_http/test/*`
- `packages/nexa_http/README.md`
- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http/example/nexa_http_dio_consumer/*`
- `packages/nexa_http/tool/benchmark_nexa_http_vs_dio.dart`

## Migration Outcome

After this change, the public package should read as a single-path transport SDK:

- define request
- execute request
- read response

There should be no second integration style, no encoding-specific request helpers, and no public abstraction that exists only to support the removed Dio adapter.
