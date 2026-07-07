# ADR-0001: public Dart SDK root API

## 状态

Accepted

## 背景

`nexa_http` 的宿主 runtime 入口是 `package:nexa_http/nexa_http.dart`。宿主业务代码需要处理 HTTP 概念，而不是 native runtime setup、FFI lifecycle、platform carrier registration 或 artifact resolver。

仓库 README、`packages/nexa_http/README.md`、Flutter SDK 编写契约和当前代码都要求宿主 runtime 示例只 import `nexa_http` 主包 API。历史设计文档中的 OkHttp-style public surface 方向已经提炼到本 ADR，原历史文档已在 ADR 提取后删除。

## 决策

`packages/nexa_http` 是 `public Dart SDK`。Root API 只暴露 app-facing HTTP semantics：

- `NexaHttpClient`
- `NexaHttpClientBuilder`
- `Request`
- `RequestBuilder`
- `RequestBody`
- `Response`
- `ResponseBody`
- `Headers`
- `MediaType`
- `Call`
- `Callback`
- `NexaHttpException`

Runtime lifecycle、dynamic-library loading、platform registration、native artifact layout、FFI ownership details 和 carrier integration helpers 必须留在内部 package、内部 library 或 carrier package 中，不进入 root public API。

## 后果

- 架构 review 不应建议把 carrier/runtime/FFI setup 暴露给宿主 App 作为标准用法。
- README、示例和 clean-host consumer 必须守住 `package:nexa_http/nexa_http.dart` runtime import。
- 新增 public root API 时，需要证明它是 HTTP 语义，而不是 native integration 细节。
- `public Dart SDK` 可以通过内部 module 使用 `native transport`，但不把该 transport 的 lifecycle 变成宿主责任。

## 替代方案

- 暴露 runtime warm-up / shutdown / registration API：拒绝。它会把 SDK 内部 lifecycle 外包给宿主 App。
- 让宿主直接 import carrier package runtime helper：拒绝。carrier dependency 是 package composition，不是 app-facing runtime API。
- 保留多个 public execution facade，例如 Dio adapter 或其他并行入口：不作为当前 ADR baseline。未来如果重新引入，需要新的 ADR。

## 当前来源

- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http/README.md`
- `packages/nexa_http/lib/nexa_http.dart`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
- `.trellis/tasks/archive/2026-07/07-06-domain-model-architecture-review/design.md`
