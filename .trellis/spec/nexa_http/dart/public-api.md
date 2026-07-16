# 公开 HTTP API 契约

本规范把 [ADR-0001](../../../../docs/adr/0001-public-dart-sdk-root-api.md)、[ADR-0006](../../../../docs/adr/0006-response-body-single-consumption-ownership.md)、[ADR-0007](../../../../docs/adr/0007-request-body-transferred-ownership.md) 和 [ADR-0008](../../../../docs/adr/0008-typed-public-http-failure-taxonomy.md) 落到 `packages/nexa_http` 的当前源码与测试。

## Root surface

- 唯一宿主 runtime 入口是 [`lib/nexa_http.dart`](../../../../packages/nexa_http/lib/nexa_http.dart)。
- Root export 只包含 `NexaHttpClient`、builder、Request/Response、body、Headers、MediaType、Call、`NexaHttpException` 和 `NexaHttpFailureKind` 等 HTTP 语义。
- generated bindings、carrier registration、artifact resolver、native ownership helper 和 platform type 必须留在 `lib/src/` 或 owner package，不能成为第二入口。
- 清理意外公开的实现细节时直接删除旧 export/library；不加 deprecated alias、forwarder 或兼容 wrapper。

## Execution and ownership

- `NexaHttpClient.newCall(Request)` 创建 one-shot `Call`；唯一执行入口是 `Call.execute()`，唯一取消入口是幂等 `Call.cancel()`。
- 不提供 `Callback`、`enqueue()`、`clone()` 或 client-level `execute(request)` 平行 facade；重复请求通过新的 Call 表达。
- [`RequestBody.takeBytes`](../../../../packages/nexa_http/lib/src/api/request_body.dart) 接管调用者的 `Uint8List`，构造、mapper 和 DTO handoff 不复制；非空 dispatch 只在写入 FFI-owned memory 时复制一次。
- [`ResponseBody`](../../../../packages/nexa_http/lib/src/api/response_body.dart) 只能消费一次：`string()` 直接 decode 后释放，native-backed `bytes()` 恰好复制一次后释放，`close()` 零复制且幂等；第二次消费抛 `StateError`。
- Request/Response 不提供伪 streaming 的 single-event `byteStream()`，也不公开 mutable backing bytes 或 native adoption helper。

## Failure contract

- [`NexaHttpException`](../../../../packages/nexa_http/lib/src/api/nexa_http_exception.dart) 是唯一 public HTTP Failure，稳定 kind 只有 `canceled`、`timeout`、`network`、`invalidRequest`、`configuration`、`unavailable`、`internal`。
- 应用控制流只依赖 kind；message、URI 和 diagnostics 用于定位，不承诺内部 schema。
- HTTP 4xx/5xx 返回普通 Response；second execute、use-after-close、second body consumption 等 programmer misuse 使用 `StateError`。
- 未知 native code 或 malformed payload 收敛为 `internal`；registration、library、symbol、bootstrap 或 dispatch unavailable 收敛为 `unavailable`。

## Required tests

- [`nexa_http_api_export_test.dart`](../../../../packages/nexa_http/test/nexa_http_api_export_test.dart) 和 [`public_api_negative_test.dart`](../../../../packages/nexa_http/test/public_api_negative_test.dart) 锁定正向 allowlist 与内部 symbol absence。
- [`call_api_test.dart`](../../../../packages/nexa_http/test/call_api_test.dart) 覆盖 one-shot execution、取消 winner 和禁止的平行入口。
- [`request_body_test.dart`](../../../../packages/nexa_http/test/request_body_test.dart) 与 [`response_body_test.dart`](../../../../packages/nexa_http/test/response_body_test.dart) 覆盖 transferred/single-consumption ownership 和复制次数。
- [`nexa_http_failure_kind_test.dart`](../../../../packages/nexa_http/test/nexa_http_failure_kind_test.dart) 与 error mapper tests 覆盖完整 taxonomy 和 unknown/malformed 归一化。

任何 root surface 或 lifecycle 变化都先写行为测试，并运行 `fvm dart test packages/nexa_http/test`。
