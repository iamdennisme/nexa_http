# Deepen native transport module - Design

## Architecture

The target shape is a deeper internal `native transport` module inside `packages/nexa_http`.

The public SDK remains:

```text
NexaHttpClient -> Call / RealCall -> internal native transport -> uniform C ABI
```

The deepened module should expose a narrow internal interface to `NexaHttpClient` / `RealCall` and absorb the wiring that is currently spread across `NexaHttpTransportSession`, DTO mappers, response mapper, and native data source lease handling.

## Boundaries

### Public Dart SDK

`NexaHttpClient`, `Call`, `Request`, `Response`, and `NexaHttpException` remain app-facing HTTP semantics only. No native integration or lifecycle detail becomes public API.

`RealCall` can keep public call state:

- request identity
- `isExecuted`
- `isCanceled`
- clone behavior
- callback dispatch for `enqueue`

It should not know about FFI request ids, native result ownership, callback registry draining, client lease ids, or native data source creation.

### Native transport module

The internal `native transport` module owns:

- native client lease creation and reuse
- close/dispose lifecycle
- request DTO mapping
- response mapping
- cancellation handoff between `Call` state and native execution
- data source adapter selection through `NexaHttpNativeDataSourceFactory`

The preferred stable interface is intentionally small:

```dart
Future<Response> execute(
  Request request, {
  required bool Function() isCanceled,
  required void Function(CancelNativeRequest cancelRequest) onCancelReady,
});

Future<void> close();
```

Constructor wiring should also shrink. `NexaHttpClient` should not need to pass request/config/response mappers individually when the production transport can own those defaults.

### FFI data source adapter

`FfiNexaHttpNativeDataSource` remains the adapter to the generated bindings and the `uniform C ABI`.

It may keep low-level concerns that are specific to the ABI adapter:

- request body allocation and transfer
- `nexa_http_client_execute_async`
- native callback function
- pending request registry
- late callback result free
- response body adoption and finalizer setup

This task can deepen the Dart transport without merging every FFI helper into one file. The important constraint is that upstream modules see one deeper `native transport` interface instead of knowing mapper and lease details.

## Data Flow

```text
public Request
  -> RealCall public call state
  -> native transport execute
  -> ClientOptions + Request -> NativeHttpRequestDto
  -> native data source execute(client lease, request dto)
  -> TransportResponse
  -> public Response
```

Cancellation flow:

```text
Call.cancel()
  -> RealCall marks public state
  -> installed native cancel callback is invoked at most once
  -> native transport/data source completes with NexaHttpException(code: canceled)
```

Close flow:

```text
NexaHttpClient.close()
  -> native transport close()
  -> close native lease when opened
  -> dispose data source once
```

## Compatibility

- Public imports and exports remain unchanged.
- Existing tests should continue to compile except where they directly target the old internal transport constructor. Those tests may move to the new stable internal interface.
- No generated FFI bindings should change.
- No Rust, carrier, hook, artifact, or release consumer behavior should change.

## TDD Strategy

Use one vertical slice at a time:

1. RED: add a native transport contract test through the new/deepened stable internal interface. The first RED can be a compile failure because the stable interface does not exist yet.
2. GREEN: introduce the smallest module/interface implementation, initially by extracting or wrapping current `NexaHttpTransportSession` behavior.
3. REFACTOR: move mapper defaults and lease lifecycle behind that module, then rerun the focused tests.
4. RED/GREEN as needed for cancellation and close behavior if the extraction reveals missing coverage.

Tests should prefer observable behavior:

- public `Call` tests for user-visible cancellation/execution semantics
- stable internal `native transport` contract tests for lease/reuse/close behavior
- FFI data source tests for ABI adapter behavior and ownership

## Tradeoffs

- A wrapper-only first step is acceptable only as a GREEN step for TDD. The refactor must then shrink the interface or remove redundant shallow wiring before the task is complete.
- Moving every FFI helper into one module in this task would increase risk and blast radius. Keep ABI adapter internals stable unless a failing test forces a change.
- Keeping `RealCall` as the owner of public call state avoids changing the app-facing `Call` semantics while still allowing native cancellation handoff to move behind the transport interface.

## Rollback Shape

If the extraction creates behavior drift, revert only the new transport module and `NexaHttpClient` wiring while keeping added behavior tests when they describe valid existing behavior. Do not modify carrier/native artifacts to compensate for Dart transport issues.
