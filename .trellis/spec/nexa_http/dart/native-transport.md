# Native Transport 契约

本规范把 [ADR-0003](../../../../docs/adr/0003-unified-async-ffi-transport.md)、body ownership ADR 和 public failure taxonomy 落到 Dart/FFI transport。所有平台共享同一 request、callback、cancellation 和 result pipeline。

## Data flow

```text
Request / ClientOptions
  -> mapper 与 DTO
  -> FFI config/request encoder
  -> pending request registry
  -> nexa_http_client_execute_async
  -> single callback result decoder
  -> TransportResponse mapper
  -> public Response / NexaHttpException
```

- [`nexa_http_native_transport.dart`](../../../../packages/nexa_http/lib/src/internal/transport/nexa_http_native_transport.dart) 拥有 Dart 侧 transport interface 与 lifecycle。
- [`ffi_nexa_http_native_data_source.dart`](../../../../packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart) 只消费 internal bindings factory，不寻找动态库路径。
- 平台差异停在 carrier registration、CodeAsset identity 和 Rust Platform Capability source，不分叉 Dart request execution model。

## Request and callback ownership

- Request encoder 成功完成 native allocation/copy 后，才把 request ID 标记为 callback-outstanding；pre-dispatch failure 不得留下等待一个不可能 callback 的 entry。
- 每个非 null callback result 只有 response decoder 能裁决 ownership：error、empty、malformed 立即 free，非空成功把 exactly-once release 转交 body owner。
- Empty response 在 free 前 snapshot status、URL 等标量；free 后不读取 FFI struct view。
- Mapper 和 public Response 传递同一个 body owner，不做 defensive full-body copy；异常 handoff 必须释放尚未转移的 owner。

## Cancellation linearization

- native cancel 返回 `1` 表示 cancel 先于 Callback Commit，native 保证不再 callback；Dart 才能完成 typed canceled 并移除 outstanding entry。
- 对成功 dispatch 且仍 outstanding 的 request，cancel 返回 `0` 表示 callback 已 commit；Dart 保留 entry 并等待 callback，不得覆盖 terminal result。
- unknown/already-removed request 的 `0` 不承诺 callback。`NativeCallable` 只能在所有仍可能 callback 的 entry 清空后关闭。
- cancel-before-execute、cancel-in-flight、response-wins、cancel-wins、重复 cancel、second execute 和 cancel-after-terminal 都必须有状态机测试。

## Error normalization

- Native JSON 先解码为内部 DTO，再由 mapper 收敛为 public taxonomy；raw native code、stage 和 schema exception 不得泄漏成控制流。
- allocator/copy/ABI/schema/invalid handle 失败归为 `internal`；未注册 bindings、symbol 或 dispatch unavailable 归为 `unavailable`。
- native `details` 原样保留为 diagnostics；malformed JSON 自身不能冒充 network 或 configuration failure。

## Required tests

- [`ffi_nexa_http_request_encoder_test.dart`](../../../../packages/nexa_http/test/ffi_nexa_http_request_encoder_test.dart) 覆盖 allocation、copy、empty body 和 pre-dispatch failure。
- [`ffi_nexa_http_response_decoder_test.dart`](../../../../packages/nexa_http/test/ffi_nexa_http_response_decoder_test.dart) 覆盖 result free、empty snapshot 和 adopted owner handoff。
- [`ffi_nexa_http_pending_request_registry_test.dart`](../../../../packages/nexa_http/test/ffi_nexa_http_pending_request_registry_test.dart) 与 [`ffi_nexa_http_native_data_source_test.dart`](../../../../packages/nexa_http/test/ffi_nexa_http_native_data_source_test.dart) 覆盖 cancellation acknowledgment、callback lifetime 和 dispose drain。
- [`nexa_http_native_transport_test.dart`](../../../../packages/nexa_http/test/nexa_http_native_transport_test.dart) 与 response mapper tests 覆盖 transport/public 边界。

FFI contract 变化还必须同步 Rust core、四个平台 FFI crate、generated bindings 和 ABI contract tests。
