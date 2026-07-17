# Deepen Dart native transport module - Design

## Target Architecture

```text
public API + shared internal seams
  <- NexaHttpClient
       -> internal/native_transport/nexa_http_native_transport.dart
            -> request/config mappers + DTOs
            -> data source factory + FFI adapter/helpers
            -> pending registry + response decoder/mapper
            -> nexa_http_native_internal bindings
```

The target feature directory is intentionally flat:

```text
lib/src/internal/native_transport/
  nexa_http_native_transport.dart
  nexa_http_native_data_source.dart
  nexa_http_native_data_source_factory.dart
  nexa_http_testing_overrides.dart
  transport_response.dart
  nexa_http_response_mapper.dart
  native_http_client_config_dto.dart
  native_http_error_dto.dart
  native_http_error_dto.freezed.dart
  native_http_error_dto.g.dart
  native_http_request_dto.dart
  native_http_client_config_mapper.dart
  native_http_error_mapper.dart
  native_http_request_mapper.dart
  ffi_nexa_http_client_config_encoder.dart
  ffi_nexa_http_native_data_source.dart
  ffi_nexa_http_pending_request_registry.dart
  ffi_nexa_http_request_encoder.dart
  ffi_nexa_http_response_decoder.dart
```

Recreating `dto/`, `mappers/`, `sources/` or `native_bridge/` below the feature would preserve the old topology at a smaller scale. The existing file prefixes are sufficient navigation for 19 files.

## Boundaries

### Client and facade

`NexaHttpClient` imports only `internal/native_transport/nexa_http_native_transport.dart`. It passes `ClientOptions` and delegates `execute/close`; it does not select a low-level factory.

`NexaHttpNativeTransport` keeps optional constructor injection for focused tests, but production default selection moves inside the module:

```dart
NexaHttpNativeTransport({
  required ClientOptions options,
  NexaHttpNativeDataSourceFactory? dataSourceFactory,
  NexaHttpResponseMapper responseMapper = const NexaHttpResponseMapper(),
}) : _dataSourceFactory = dataSourceFactory ??
       NexaHttpTestingOverrides.nativeDataSourceFactory ??
       const NexaHttpNativeDataSourceFactory();
```

This preserves test injection while making the production client depend on one facade.

### Shared seams that stay outside

- `internal/body/response_body_owner.dart` remains shared by public `ResponseBody` and native decoder/mapper. Moving it would create an API↔transport cycle.
- `internal/config/client_options.dart` remains shared by `NexaHttpClient` and transport mapping.
- `internal/errors/nexa_http_failures.dart` remains shared by `RealCall`, factory, encoder and transport.
- `client/real_call.dart` remains the public Call state owner and only receives the existing execute function shape.

### Lifecycle owners

No state machine is redesigned:

- `NexaHttpNativeTransport`: lazy data source, native client lease, lease retry, repeated execution reuse, close/dispose and public response handoff.
- `RealCall`: `isExecuted`, monotonic `isCanceled`, pre-execute cancel and at-most-once forwarding once native cancellation becomes available.
- `FfiNexaHttpNativeDataSource` plus pending registry: request ID, encode-before-register, dispatch acceptance, cancel acknowledgment, callback drain and callback handle disposal.
- response decoder/body owner: binary result arbitration and exactly-once native body/result release.

## Dependency Contract

`test/native_transport_dependency_test.dart` scans production imports and asserts:

1. old `data`, `native_bridge`, `internal/transport` and `internal/testing` directories do not exist;
2. production files outside the feature can enter it only from `nexa_http_client.dart`, through `nexa_http_native_transport.dart`;
3. feature files do not import `client/`, `nexa_http_client.dart` or any legacy path;
4. no forwarding/barrel library is added for the old structure.

The test parses Dart import directives only; no analyzer dependency is added.

## Data And Ownership Flow

```text
Request + ClientOptions
  -> NativeHttpRequestMapper / NativeHttpClientConfigMapper
  -> canonical DTO buffers
  -> FFI request encoder (one Dart-to-native body copy)
  -> pending registry / execute_async / callback
  -> response decoder (result ownership decision)
  -> TransportResponse + ResponseBodyOwner
  -> response mapper -> public Response
```

No extra DTO conversion, body copy, cancellation branch or error normalization is introduced by the move.

## Documentation Cutover

Current source references in the package spec index, native transport spec and ADR-0003/0006/0007/0008 are updated to `internal/native_transport`. Archived task artifacts remain immutable historical evidence.

## Flutter SDK Compatibility

- Host dependency and runtime import remain unchanged.
- No carrier/internal package becomes public.
- Artifact preparation, registration, download, cache, packaging and failure envelopes are untouched.
- No formal config surface is added.
- Clean-host verification exercises the same root API and standard Flutter build chain; the source move is invisible to consumers.

## TDD And Rollback

1. RED the dependency contract against the current old directories.
2. Move the complete feature atomically and update imports/parts.
3. GREEN the dependency contract, then run lifecycle/ownership suites.
4. Run codegen; generated content must remain semantically identical aside from path placement.
5. If behavior changes, revert the move as one unit. Do not add old-path forwarders as rollback scaffolding.
