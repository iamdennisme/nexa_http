# nexa_http Dart 规范

> `packages/nexa_http` 拥有唯一公开 Dart HTTP API 和内部 Native Transport；它不拥有 artifact 下载、平台注册或动态库路径解析。

## Scope

- `lib/nexa_http.dart` 与 `lib/src/api/` 的公开 HTTP 语义
- `lib/src/internal/native_transport/` 的垂直 Native Transport module
- package tests 中的 public surface、failure taxonomy、cancellation 和 body ownership contract

## 规范索引

| 规范 | 说明 |
| --- | --- |
| [公开 HTTP API](./public-api.md) | root export、Call、body ownership 与 typed failure |
| [Native Transport](./native-transport.md) | Dart/FFI request pipeline、cancellation、callback 与 result ownership |

## Pre-Development Checklist

- [ ] 修改公开 API 前阅读 [公开 HTTP API](./public-api.md) 和 [Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md)。
- [ ] 修改 FFI execution、callback、cancellation 或 ownership 前阅读 [Native Transport](./native-transport.md) 和共享 [跨层思考指南](../../guides/cross-layer-thinking-guide.md)。
- [ ] 保持宿主唯一 runtime import 为 `package:nexa_http/nexa_http.dart`。
- [ ] 保持 carrier registration、artifact lifecycle 和 generated platform bindings 在内部 owner 中。

## Quality Check

- [ ] `fvm dart analyze packages/nexa_http` 通过。
- [ ] `fvm dart test packages/nexa_http/test` 通过。
- [ ] public export、typed failure、request/response body ownership 和 cancellation tests 覆盖本次行为。
- [ ] 没有新增 carrier/runtime escape hatch、隐式 artifact lookup 或兼容 API。
