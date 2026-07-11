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
- `NexaHttpException`
- `NexaHttpFailureKind`

Runtime lifecycle、dynamic-library loading、platform registration、native artifact layout、FFI ownership details 和 carrier integration helpers 必须留在内部 package、内部 library 或 carrier package 中，不进入 root public API。

`Call` 是唯一 request execution object：`NexaHttpClient.newCall(Request)` 创建一次性 Call，`Call.execute()` 返回 `Future<Response>`，`Call.cancel()` 表达取消意图。Dart Future 是唯一异步完成模型；不提供 `Callback`/`enqueue()`、`Call.clone()`、`NexaHttpClient.execute(Request)` 或其他并行 execution facade。

Cancellation 在所有生命周期阶段都幂等，`isCanceled` 记录单调的 cancellation intent。Dart/native handshake 必须在线性化点决定 terminal winner：native 接受 cancel 时必须保证 callback 被抑制，`execute()` 以 `NexaHttpException(kind: NexaHttpFailureKind.canceled)` 结束；callback 已 commit 时 cancel 不得覆盖它，response/error 继续完成 Future。Response 已完成后的取消不改变结果且不再次转发 native cancel，第二次 execute 继续作为 `StateError` 暴露 programmer misuse。

Byte-backed request body 只通过 `RequestBody.takeBytes(...)` 构造并显式转移 buffer ownership。旧 `RequestBody.bytes(...)` factory、公开实例 `bytes()`、`byteStream()` 和 `payloadBytes` 全部删除，不提供兼容入口；`RequestBody.text(...)`、`contentLength` 和 `contentType` 保留。

`NexaHttpException` 是唯一 public HTTP Failure 类型，并通过 typed `NexaHttpFailureKind` 暴露稳定类别。Native code、FFI stage 和内部 message 只能作为 diagnostics，不得直接成为 public control-flow value。HTTP 4xx/5xx 继续作为 `Response`，programmer/lifecycle misuse 继续使用 `StateError`。

意外暴露不自动形成长期兼容承诺。生成的 FFI bindings、native response body adoption helper、raw request payload accessor 等实现细节一旦被发现进入 public surface，必须直接移回内部边界并删除旧入口，不提供 deprecated alias、转发 wrapper 或兼容 library。此类删除作为明确 breaking change 进入版本和 CHANGELOG。

## 后果

- 架构 review 不应建议把 carrier/runtime/FFI setup 暴露给宿主 App 作为标准用法。
- README、示例和 clean-host consumer 必须守住 `package:nexa_http/nexa_http.dart` runtime import。
- 新增 public root API 时，需要证明它是 HTTP 语义，而不是 native integration 细节。
- `public Dart SDK` 可以通过内部 module 使用 `native transport`，但不把该 transport 的 lifecycle 变成宿主责任。
- Public API contract 必须包含负向检查，证明 FFI bindings、ownership helper 和 carrier/runtime 类型无法通过受支持的 root API 导入。
- Request Body contract 必须通过 `takeBytes` 明示所有权转移，避免公开 read API 泄漏 mutable backing buffer 或为了 defensive read 增加整段复制。
- Public failure contract 必须穷举稳定 Failure Kind，并把未知 native/FFI failure 收敛到 `unavailable` 或 `internal`，不得让新增 Rust code 自动扩张 Dart API。
- 清理意外 public API 时，同一个任务必须删除旧 export、旧 library、旧测试用法和旧文档，不保留兼容中间态。
- Cancellation tests 必须同时证明 terminal winner 与 callback lifetime：accepted cancel 后不得再 callback；callback commit 后 cancel 不得完成 canceled；dispose 不得提前关闭仍可能被调用的 callback handle。

## 替代方案

- 暴露 runtime warm-up / shutdown / registration API：拒绝。它会把 SDK 内部 lifecycle 外包给宿主 App。
- 让宿主直接 import carrier package runtime helper：拒绝。carrier dependency 是 package composition，不是 app-facing runtime API。
- 保留多个 public execution facade，例如 Dio adapter 或其他并行入口：不作为当前 ADR baseline。未来如果重新引入，需要新的 ADR。
- Java-style `Callback`/`enqueue()` 与 `Call.clone()`：拒绝。Future 已经表达异步完成，重复操作通过 `newCall(request)` 创建新的 Call。
- 在 client 上增加直接 `execute(request)` convenience：拒绝。它会和 Call 形成第二套 execution/cancellation surface。

## 当前来源

- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http/README.md`
- `packages/nexa_http/lib/nexa_http.dart`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
- `.trellis/tasks/archive/2026-07/07-06-domain-model-architecture-review/design.md`
