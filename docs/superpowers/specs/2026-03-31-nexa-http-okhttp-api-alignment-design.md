# Nexa HTTP OkHttp API Alignment Design

## Status

Approved in chat on 2026-03-31.

## Context

The current `nexa_http` package exposes too much of its transport startup model
through the public API:

- `NexaHttp.warmUp()`
- `NexaHttp.shutdown()`
- `NexaHttpClient.open(...)`
- runtime registration APIs exported from the root package
- example code that explicitly works around SDK initialization timing

That is the wrong public boundary. End-user code should deal with HTTP concepts,
not worker isolates, native runtime setup, or FFI lifecycle rules.

The desired public mental model should align with OkHttp:

- a lightweight client owns shared defaults and execution infrastructure
- a request describes one HTTP operation
- a call represents one executable request
- a response exposes metadata and a body abstraction
- initialization is internal and lazy

This design supersedes the end-user API direction described in:

- `docs/superpowers/specs/2026-03-29-nexa-http-public-api-simplification-design.md`
- the public-startup portions of
  `docs/superpowers/specs/2026-03-30-nexa-http-worker-init-design.md`

## Goals

- Make the end-user API feel like OkHttp, adapted to Dart idioms.
- Restrict the root public package surface to HTTP semantics.
- Move all worker/runtime/FFI initialization behind internal lazy execution.
- Keep platform carrier packages working through a narrow package integration SPI,
  not through the end-user root API.
- Remove example-level startup orchestration that exists only to work around SDK
  initialization behavior.

## Non-Goals

- Implement interceptors in this phase.
- Preserve source compatibility with `NexaHttpClient.open(...)`,
  `NexaHttp.warmUp()`, or `NexaHttp.shutdown()`.
- Redesign the Rust transport core in the same phase.
- Add request streaming or response streaming beyond a body abstraction over the
  existing buffered transport path.
- Introduce Dio adapters or alternate execution facades.

## Design Principles

- The end-user root API must expose HTTP objects only.
- Initialization is an internal guarantee, not an external lifecycle API.
- The client constructor must be lightweight and synchronous.
- The first real request may lazily initialize transport resources.
- Platform/package integration SPI may exist, but it must not pollute the main
  end-user mental model.

## Public Surface

### End-User Root Library

`package:nexa_http/nexa_http.dart` should export only end-user HTTP types:

- `NexaHttpClient`
- `NexaHttpClientBuilder`
- `Call`
- `Request`
- `RequestBuilder`
- `RequestBody`
- `Response`
- `ResponseBody`
- `Headers`
- `MediaType`
- `Callback` if async callback execution is retained
- `NexaHttpException`

The root library must not export:

- worker lifecycle APIs
- runtime registration APIs
- FFI loader/runtime types
- carrier-package integration utilities

### Platform Integration SPI

Carrier packages still need a stable way to register or provide a runtime hook.
That should move to a secondary library, not the root API.

Introduce a dedicated package SPI library:

- `package:nexa_http/nexa_http_platform.dart`

This library may expose:

- `NexaHttpNativeRuntime`
- `registerNexaHttpNativeRuntime(...)`
- package-internal runtime bootstrap helpers if needed

This is a supported package integration surface for carrier packages, not an
end-user API. End-user docs should not mention it.

## OkHttp-Aligned API Model

### Client

`NexaHttpClient` becomes a lightweight immutable object that owns defaults and
shared execution infrastructure.

Expected end-user shape:

```dart
final client = NexaHttpClient();

final customClient = NexaHttpClientBuilder()
    .baseUrl(Uri.parse('https://api.example.com/'))
    .callTimeout(const Duration(seconds: 10))
    .userAgent('nexa_http/2.0')
    .build();
```

The client constructor and builder must not:

- load a native library
- create a native client
- start a worker proactively

### Request

`Request` becomes the end-user request object. `RequestBuilder` is the main
construction path.

Expected shape:

```dart
final request = RequestBuilder()
    .url(Uri.parse('https://example.com/healthz'))
    .get()
    .build();
```

Use HTTP method strings or builder verbs, not a public `NexaHttpMethod` enum.

### Call

`Call` represents one executable request created from a client:

```dart
final call = client.newCall(request);
final response = await call.execute();
```

Expose:

- `Future<Response> execute()`
- `void cancel()`
- `Call clone()`
- optional `enqueue(Callback callback)`

Initialization occurs when a call executes, not when the client is constructed.

### Response / ResponseBody

`Response` carries response metadata and a `ResponseBody`.

`ResponseBody` wraps the currently buffered bytes but presents an API that can
evolve later:

- `Future<List<int>> bytes()`
- `Future<String> string()`
- `Stream<List<int>> byteStream()`
- `void close()`

Internally the implementation may still be backed by fully buffered body bytes
from Rust for this phase.

## Layering Model

### 1. Public HTTP API Layer

Location:

- `packages/nexa_http/lib/nexa_http.dart`
- `packages/nexa_http/lib/src/api/*`

Responsibilities:

- stable end-user HTTP types
- no worker or FFI knowledge

### 2. Client / Call Facade Layer

Location:

- `packages/nexa_http/lib/src/client/*`
- lightweight public client entrypoint file if retained outside `api/`

Responsibilities:

- implement `NexaHttpClient`
- implement `RealCall`
- merge defaults with request-local settings
- delegate execution to the internal engine

### 3. Internal Engine Layer

Location:

- `packages/nexa_http/lib/src/internal/engine/*`

Responsibilities:

- lazy initialization orchestration
- process-wide shared state
- config-keyed client pooling
- execution dispatch and result mapping

This layer owns the answer to:

"What happens on the first real request?"

### 4. Internal Worker Layer

Location:

- `packages/nexa_http/lib/src/internal/worker/*`

Responsibilities:

- isolate lifecycle
- host/worker protocol
- worker-side request execution
- lifecycle failure handling

### 5. Internal Native Bridge Layer

Location:

- `packages/nexa_http/lib/src/internal/ffi/*`

Responsibilities:

- FFI bindings
- DTO/ABI mapping
- native body/result ownership

### 6. Internal Platform Runtime Layer

Location:

- `packages/nexa_http/lib/src/internal/platform/*`

Responsibilities:

- dynamic library discovery
- platform-specific runtime bootstrap
- carrier-package integration

### 7. Carrier Package Layer

Location:

- `packages/nexa_http_native_*`

Responsibilities:

- platform packaging
- plugin registration
- runtime bootstrap into the SPI layer

### 8. Native Core Layer

Location:

- `native/*`

Responsibilities:

- actual transport execution
- connection pooling
- redirects / TLS / proxy / timeout behavior

## Initialization Model

The initialization flow must become fully internal:

1. user constructs `NexaHttpClient`
2. user constructs `Request`
3. user calls `client.newCall(request).execute()`
4. call asks the internal engine to execute
5. engine ensures worker/runtime/FFI/native client availability lazily
6. request executes
7. response maps back to public `Response`

There is no public prewarm API in the root package.

If a prewarm hook remains useful for benchmarks or tests, keep it internal or in
the platform SPI, not the main end-user surface.

## Runtime Registration Direction

End-user runtime registration APIs should be removed from
`package:nexa_http/nexa_http.dart`.

Carrier packages should move to the dedicated SPI library:

- current: `package:nexa_http/nexa_http_native_runtime.dart`
- target: `package:nexa_http/nexa_http_platform.dart`

This keeps:

- end-user API clean
- carrier integration stable
- private `src/` imports unnecessary

## Example Direction

The example app should demonstrate standard HTTP usage only:

- create a client
- build a request
- execute a call
- display response data

The example should not:

- delay initialization after the first frame to avoid SDK startup cost
- expose runtime timing workarounds as normal usage
- depend on worker internals

Profiling utilities may exist separately, but not as the primary example flow.

## Testing Strategy

### Public API Tests

Test only public types and behavior:

- request builder behavior
- client/newCall behavior
- response body helpers
- integration tests through the public API

Public tests must not import `package:nexa_http/src/...`.

### Internal Tests

Test internal concerns separately:

- lazy engine initialization
- worker protocol
- shutdown/failure semantics
- native client pool reuse

### Example Tests

Example tests must use only the root public API and local example fakes.

## Impacted Files

Expected work includes:

- `packages/nexa_http/lib/nexa_http.dart`
- `packages/nexa_http/lib/nexa_http_native_runtime.dart`
- `packages/nexa_http/lib/nexa_http_platform.dart` (new)
- `packages/nexa_http/lib/src/api/*`
- `packages/nexa_http/lib/src/client/*` (new)
- `packages/nexa_http/lib/src/internal/engine/*` (new)
- `packages/nexa_http/lib/src/internal/worker/*` (new home for current worker files)
- `packages/nexa_http/lib/src/internal/ffi/*` (re-homed current FFI bridge files as needed)
- `packages/nexa_http/lib/src/internal/platform/*` (re-homed current loader/runtime files as needed)
- `packages/nexa_http/test/*`
- `packages/nexa_http/example/*`
- `packages/nexa_http/README.md`
- `packages/nexa_http/example/README.md`
- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http_native_*/lib/src/*`
- `packages/nexa_http_native_*/test/*`

## Migration Outcome

After this refactor:

- end-user code sees one clean OkHttp-like HTTP API
- initialization becomes an internal implementation detail
- worker/runtime/FFI concerns stay behind internal boundaries
- carrier packages integrate through a dedicated SPI instead of polluting the
  end-user root surface
