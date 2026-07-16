# ADR-0008: Typed public HTTP Failure taxonomy

## 状态

Accepted

## 背景

当前 `NexaHttpException.code` 直接接收 Rust/FFI error code，使 `ffi_invalid_response`、`native_bootstrap_failed`、`serialization` 等实现拓扑进入 public API。新增一个 native code 会在没有 Dart API 决策的情况下自动产生新的宿主控制流值；同时 `statusCode` 在生产错误中没有赋值，`isTimeout` 又与 timeout code 重复。

## 决策

`v2.0.0` 保留一个 `NexaHttpException`，使用 typed `NexaHttpFailureKind` 暴露唯一稳定分类：`canceled`、`timeout`、`network`、`invalidRequest`、`configuration`、`unavailable`、`internal`。

Public exception 只保留 `kind`、`message`、可选 `uri` 和可选 `diagnostics`。删除 string `code`、error `statusCode`、`isTimeout` 和 `details`，不提供 alias。Application control flow 只能依赖 `kind`；message、native code、FFI stage 和 native message 只用于诊断，不承诺稳定 schema。

映射边界如下：

- cancellation -> `canceled`
- reqwest timeout -> `timeout`
- 其他 HTTP execution network failure -> `network`
- URL、method、header 或 request validation -> `invalidRequest`
- client 或 proxy configuration failure -> `configuration`
- carrier registration、dynamic-library/symbol loading、bootstrap 或 dispatch availability failure -> `unavailable`
- ABI corruption、malformed error payload、invalid native handle、serialization、unknown native code -> `internal`

HTTP 4xx/5xx 是正常 `Response`。第二次 Call execution、use-after-close、第二次 Response Body consumption 等 programmer/lifecycle misuse 使用 `StateError`。

## 后果

- Rust 可以增加内部诊断 code，而不自动扩张 public Dart taxonomy。
- 未知或损坏的 native error payload 必须在 Dart normalization boundary 收敛，不能暴露 `FormatException`、raw `StateError` 或 callback implementation error。
- `network` 暂不细分 DNS、connect、TLS 或 response-body I/O；未来若产品确实需要稳定 retry policy，必须通过新的 API/ADR 扩展，而不是透传 reqwest 分类。
- Error mapping、loader、bootstrap、dispatch、cancellation 和 malformed-payload tests 必须共同证明同一 public taxonomy。

## 拒绝的替代方案

- Sealed exception hierarchy：拒绝，因为增加 public type 数量，并使新增 subtype 影响 exhaustive pattern matching。
- Namespaced string codes：拒绝，因为仍然依赖字符串注册表和拼写纪律。
- 继续透传 Rust code：拒绝，因为 native implementation detail 会无审查地成为 public contract。

## 当前来源

- `packages/nexa_http/lib/src/api/nexa_http_exception.dart`
- `packages/nexa_http/lib/src/data/mappers/native_http_error_mapper.dart`
- `packages/nexa_http/test/nexa_http_failure_kind_test.dart`
- `.trellis/spec/nexa_http/dart/public-api.md`
- `.trellis/spec/nexa_http/dart/native-transport.md`
