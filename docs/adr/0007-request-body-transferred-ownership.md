# ADR-0007: Request Body 显式转移所有权

## 状态

Accepted

## 背景

Byte-backed Request Body 如果在构造时做 defensive snapshot，再在 FFI dispatch 时复制到 native-owned memory，会为每个请求产生两次完整 body copy。反过来，如果继续公开同一个 mutable buffer 的读取入口，调用者可以在 Request 建立后修改 payload，使“不可变 Request”与实际发送内容不一致。

## 决策

`RequestBody.takeBytes(Uint8List bytes, {MediaType? contentType})` 显式接管调用者提供的 buffer，不在构造时复制。调用者在构造后不得继续修改该 buffer。

Request mapper、内部 DTO 和 transport handoff 保持同一个 canonical Dart buffer identity。每次非空 body dispatch 恰好执行一次完整 Dart-to-native copy，将内容写入 FFI-owned request memory；这是异步 native 执行取得独立所有权的边界。空 body 不分配 native body memory，也不执行 full-body copy。

删除 `RequestBody.bytes(...)` factory、公开实例 `bytes()`、request-side `byteStream()` 和 `payloadBytes`，不提供 deprecated alias 或 forwarding wrapper。Public RequestBody 只保留 `takeBytes(...)`、`text(...)`、`contentLength` 和 `contentType`。Text body 只编码一次；encoder 已返回 `Uint8List` 时直接接管，仅 generic `List<int>` 允许一次必要的 normalization copy。

## 后果

- Public API 名字直接表达 ownership transfer，避免把借用或 defensive snapshot 当成默认语义。
- 构造、mapping 和 DTO boundary 都不得复制完整 request body；性能测试必须证明非空 dispatch 只有一次 Dart-to-native full-body copy，空 body 为零 allocation、零 copy。
- Request Body 不再提供读取或假的 streaming surface。真正的 upload streaming 需要独立设计 incremental delivery、backpressure、cancellation 和 native ownership。
- 同一个非空 Request 创建多个 Call 时，每次 dispatch 各执行一次必要的 native ownership copy，但 Request 内部 canonical Dart buffer 不重复构造。

## 拒绝的替代方案

- 构造期 snapshot：拒绝，因为加上 dispatch copy 后会固定产生两次完整 body copy。
- 保留 `bytes()` 并返回内部 buffer：拒绝，因为会泄漏已转移 ownership 的 mutable state。
- 保留 `bytes()` 并每次返回 defensive copy：拒绝，因为为非核心 introspection API 引入不受控整段复制。
- 从 public RequestBody 直接持有 native memory 实现零 dispatch copy：拒绝，因为它把 FFI lifecycle 和 native availability 泄漏进 HTTP API 构造阶段。

## 当前来源

- `packages/nexa_http/lib/src/api/request_body.dart`
- `packages/nexa_http/lib/src/internal/native_transport/ffi_nexa_http_request_encoder.dart`
- `packages/nexa_http/test/request_body_test.dart`
- `.trellis/spec/nexa_http/dart/public-api.md`
- `.trellis/spec/nexa_http/dart/native-transport.md`
