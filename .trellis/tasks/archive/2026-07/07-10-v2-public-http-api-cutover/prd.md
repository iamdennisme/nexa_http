# V2 public HTTP API clean cutover

## Goal

一次性完成 `nexa_http` 的 `v2.0.0` 公开 HTTP API，删除 FFI/native 泄漏、重复执行入口和伪 streaming API，并以明确所有权与复制预算固定 Call、Request Body、Response Body 和 HTTP Failure 语义。

## Dependencies

- 本任务是 v2 blocker 序列的第一个实现子任务，没有前置实现依赖。
- 完成后阻塞解除：Verification Catalog 的 clean-host fixtures、Native Assets runtime smoke、Release Candidate gate 都只能使用本任务的最终 API。

## Requirements

- Root runtime import 只支持 `package:nexa_http/nexa_http.dart`；generated FFI bindings 移到 `lib/src/`，`adoptResponseBodyBytes()` 等 native ownership helper 不再公开。
- `Call` 只保留 `execute()`、`cancel()`、`request`、`isExecuted`、`isCanceled`；直接删除 `Callback`、`enqueue()`、`clone()`，不新增 client-level `execute(request)`。
- Cancellation 在 execute 前、中、后均幂等；取消赢得终态竞争时返回 `NexaHttpException(kind: canceled)`，Callback Commit 先赢时 response/error 保持 terminal result；第二次 execute 为 `StateError`。
- Dart/native cancellation handshake 必须在线性化点上同时决定 terminal winner 与 callback 是否仍可能到达；不得通过永久 tombstone 或提前关闭 `NativeCallable` 规避竞态。C ABI 函数签名保持不变。
- Byte-backed request body 只通过 `RequestBody.takeBytes(...)` 构造并转移所有权；删除旧 factory、实例 `bytes()`、request `byteStream()` 和 `payloadBytes`，不留 alias。
- Request body 构造/mapping/DTO 不复制完整 buffer；非空 body 每次 dispatch 恰好一次 Dart-to-native copy，空 body 零 allocation/零 copy。Text encoder 已返回 `Uint8List` 时不得额外复制。
- `ResponseBody` 单次消费：`string()` 直接 decode native view 后释放，非空 native-adopted body 的 `bytes()` 恰好一次 native-to-Dart copy 后释放，Dart-buffered/空 body 不额外复制，`close()` 零复制幂等；删除伪 `byteStream()`。
- Public failure 只使用一个 `NexaHttpException` 和七值 `NexaHttpFailureKind`；删除 string `code`、error `statusCode`、`isTimeout`、`details`，native/FFI 信息只进入非稳定 diagnostics。
- HTTP 4xx/5xx 保持普通 `Response`；programmer/lifecycle misuse 保持 `StateError`。
- README、示例、tests、clean-host fixture API、CHANGELOG 和 release notes 只描述最终 v2 surface。
- 全过程采用 clean cutover，不提供 deprecated alias、forwarder、compatibility library 或临时双入口。

## Acceptance Criteria

- [x] Root export allowlist 只包含批准的 HTTP types，`lib/` 根目录不存在第二 FFI/native public library。
- [x] 旧 `Callback`/`enqueue`/`clone`/client execute、旧 RequestBody API、adoption helper、root bindings path 和所有兼容 wrapper 均不存在。
- [x] Cancellation race tests 覆盖 pre-execute、in-flight、response-wins、cancel-wins、callback-committed post-cancel delivery、重复 cancel 和第二次 execute。
- [x] Native cancel acknowledgment 与 callback commit 使用同一线性化规则；accepted cancel 保证抑制 callback，已 commit callback 保证 response/error wins，dispose 不永久等待也不提前关闭 callback handle。
- [x] Request body identity/copy instrumentation 证明构造与 mapper 零 full-body copy、非空 dispatch 恰好一次 copy、空 body 零 allocation/零 copy。
- [x] Response body instrumentation 证明中间零 copy、非空 native `bytes()` 恰好一次 copy、Dart-buffered/空 body 零额外 copy、`string()` direct decode 和所有路径 exactly-once release。
- [x] Failure mapping tests 穷举七种 kind，并覆盖 unknown native code、malformed payload、loader/bootstrap/dispatch 和 raw exception normalization。
- [x] Package analyze/test、公开 API negative tests 和更新后的示例全部通过。

## Out of Scope

- Dart native transport 目录重组；除非为了满足已确认外部契约必须修改，否则留给独立 deepening task。
- C ABI 函数签名、平台 artifact identity 与 Rust HTTP execution 行为；本任务只允许收紧 cancellation return-value 语义与内部状态机。
- Native Assets packaging、CI catalog 和 release workflow。
