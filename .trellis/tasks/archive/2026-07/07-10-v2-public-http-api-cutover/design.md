# V2 public HTTP API clean cutover：技术设计

## 设计目标与非目标

本任务一次性建立 `nexa_http v2.0.0` 的最终公开 HTTP API，并让执行状态、跨语言所有权和完整 body copy 次数都可以通过测试证明。

设计遵循：

- [Flutter SDK 编写契约](../../../../spec/guides/flutter-sdk-authoring-contract.md)
- [项目分层契约](../../../../spec/guides/project-layering-contract.md)
- [TDD 开发准则](../../../../spec/guides/tdd-development-policy.md)
- [Native core 质量规范](../../../../spec/nexa_http_native_core/rust/quality-guidelines.md)
- [ADR-0001](../../../../../docs/adr/0001-public-dart-sdk-root-api.md)
- [ADR-0006](../../../../../docs/adr/0006-response-body-single-consumption-ownership.md)
- [ADR-0007](../../../../../docs/adr/0007-request-body-transferred-ownership.md)
- [ADR-0008](../../../../../docs/adr/0008-typed-public-http-failure-taxonomy.md)

非目标：

- 不重组整个 Dart native transport 目录。
- 不修改 C ABI 函数签名、平台 artifact identity 或 Native Assets packaging。
- 不新增 upload/download streaming；当前 transport 仍是完整 body 交付。
- 不提供 compatibility、deprecated alias、forwarder、fallback 或临时双入口。

为了满足已经确认的 cancellation contract，本任务允许修改 Rust core 的内部 request state machine，并收紧现有 `nexa_http_client_cancel_request(...)->u8` 的返回值语义；函数签名和 generated binding 不变。

## 依赖与下游 handoff

本任务没有前置实现依赖，是历史父任务 `07-10-architecture-domain-model-review` 的第一个 v2 blocker；该父任务 artifact 未保留在当前仓库。

完成后，下游只消费本任务的最终 surface：

| 下游任务 | 本任务交付 |
|---|---|
| [Verification Catalog and CI suites](../07-10-verification-catalog-ci-suites/prd.md) | 最终 root API、negative fixture、bindings 内部路径和 package gate |
| [Four-platform Native Assets clean cutover](../07-10-native-assets-four-platform-cutover/prd.md) | 使用最终 API 的 runtime smoke fixture |
| [Immutable release candidate transaction](../07-10-immutable-release-candidate-transaction/prd.md) | 最终 package metadata、CHANGELOG 和 candidate consumer contract |
| V2 integration and release readiness（历史 task artifact 未保留） | 全量 legacy absence 与 release readiness 基线 |

[Dart native transport deepening](../07-10-deepen-dart-native-transport-module/prd.md) 是非阻断 follow-up，不得被并入本任务，也不得成为保留 forwarding file 或中间态的理由。

## Public surface allowlist

`packages/nexa_http/lib/` 根目录最终只有：

~~~text
lib/
└── nexa_http.dart
~~~

`package:nexa_http/nexa_http.dart` 只导出：

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

`nexa_http.dart` 和 `src/api/api.dart` 都使用显式 `show` allowlist。内部 source library 即使包含 transport access object，也不能经 root export 进入支持的 API。

### 删除矩阵

| 旧 surface/path | 最终结果 |
|---|---|
| `Callback`、`callback.dart` | 文件和 export 直接删除 |
| `Call.enqueue()`、`Call.clone()` | 直接删除；不提供替代 facade |
| `NexaHttpClient.execute(Request)` | 继续禁止；negative fixture 固定 absence |
| `RequestBody.bytes(...)` | 由 `RequestBody.takeBytes(...)` 唯一替代，旧 factory 删除 |
| RequestBody 实例 `bytes()`、`byteStream()`、`payloadBytes` | 全部删除 |
| ResponseBody `byteStream()` | 删除，不把完整 buffer 伪装成 stream |
| `adoptResponseBodyBytes()` | 旧函数删除；改为未 root-export 的 transport access object |
| exception `code/statusCode/isTimeout/details` | 删除；使用 `kind/message/uri/diagnostics` |
| `lib/nexa_http_bindings_generated.dart` | 移到 `lib/src/native_bridge/nexa_http_bindings_generated.dart`，旧文件删除 |
| `lib/src/internal/transport/native_response_body_bytes.dart` | forwarding file 删除，唯一实现保留在 `internal/body/` |

TDD 过程中的 RED 状态只存在于本地未完成工作，不允许形成可合并 commit。每个 GREEN slice 同时删除对应旧入口和旧消费者。

## Dart library 与内部访问边界

`RequestBody` 和 `ResponseBody` 继续使用封闭的 public `final class`，不引入 public abstract extension surface。

Dart private member 以 library 为边界，mapper 无法读取另一个 source library 的 `_bytes`。因此采用以下最小 seam：

- `request_body.dart` 内定义未 root-export 的 `RequestBodyTransportAccess`，读取 private canonical buffer。
- `response_body.dart` 内定义未 root-export 的 `ResponseBodyTransportAccess`，接收 internal ownership object。
- package internal mapper 直接 import 对应 `lib/src/api/*.dart` source library。
- public class 不增加 raw getter、native marker、release callback 或 test-only member。

这些 access object 在 Dart 语言层面是 `lib/src` symbol，但不属于支持的 package root API。Negative analyze fixture 证明宿主通过 `nexa_http.dart` 无法访问它们。

相较 public abstract base + private implementation，这个方案：

- 保持 public type 封闭，第三方无法实现伪 body；
- 避免额外 public subtype contract 和无收益的动态分派层；
- 只在已有 source library 内增加一个明确的 internal access point；
- 不改变 copy budget。

## Call 与 Cancellation 状态机

### Public Call 状态

| 当前状态 | 事件 | 结果 |
|---|---|---|
| fresh | `execute()` | `isExecuted=true`，进入 executing |
| fresh | `cancel()` | `isCanceled=true`，尚不触碰 native |
| pre-canceled | 首次 `execute()` | 占用 one-shot，返回 `kind=canceled` |
| 任意已 executed | 第二次 `execute()` | `StateError` |
| executing | 首次 `cancel()` | 记录 intent；native cancel ready 后最多转发一次 |
| executing | callback 先 commit | callback result 是 terminal winner |
| executing | cancel 先被 native 接受 | Future 以 `kind=canceled` 结束 |
| terminal | `cancel()` | 不改变 Future/result，不再次转发 native cancel |

`isCanceled` 记录 caller 是否表达过 cancellation intent，是单调 flag；即使 response 已经 terminal，随后调用 `cancel()` 也只把 intent 记为 true，不改变已经完成的结果。

Transport 保留 dispatch 前的 cancellation checks，但删除 native response 已完成后的 canceled check。Callback/response 一旦在线性化点获胜，transport 不得用稍晚的 intent flag 覆盖它。

### Native cancellation 线性化

当前 Rust runtime 的 `u8` cancel result 没有足够严格的 callback 保证：active task 可能已进入 callback，同时 cancel 仍返回成功。若 Dart 对所有 accepted cancel 保留 tombstone，会等待永不发生的 callback；若立即删除 entry，则 callback race 可能在 `NativeCallable` 关闭后到达。

最终语义固定为：

| `nexa_http_client_cancel_request` 返回值 | 语义 |
|---|---|
| `1` | cancel 在线性化点先于 callback commit；native 保证该 request 不再调用 callback |
| `0` | cancel 未被接受。若 `execute_async` 已返回 `1` 且 Dart registry 仍标记该合法 request callback-outstanding，则 Callback Commit 已发生，Dart 不得完成 canceled，callback response/error wins；unknown/already-removed ID 不承诺 callback |

Rust internal request state 至少区分：

~~~text
Pending → Active → CallbackCommitted → Removed
    └──────── cancel accepted ───────→ Removed
~~~

Callback 在构造 FFI-owned binary result 和调用函数指针之前，必须在与 cancel 相同的锁/状态机内把 request 从 `Active` 线性化为 `CallbackCommitted`：

- cancel 先看到 `Pending/Active`：抑制 callback、abort work、返回 `1`。
- completion 先提交 `CallbackCommitted`：对成功dispatch且仍outstanding的合法request，cancel 返回 `0`，callback 必须到达。
- pre-active `CanceledPending` 仍在 abort handle 安装时被清理，不产生 callback。

这只收紧已有 C ABI 的行为语义，不改变签名或 symbol set。C header 注释、Rust unit tests 和 Dart FFI race tests共同固定该 contract。

### Dart pending registry

Registry 分别追踪：

- Dart Future/completer 是否已有 terminal result；
- native callback 是否仍被 ABI 保证可能到达。

行为：

1. dispatch 失败：移除 entry，callback outstanding 归零，返回 `unavailable`。
2. native cancel 返回 `1`：完成 typed canceled、移除 entry；根据 ABI 不等待 callback。
3. native cancel 返回 `0`：该调用只会针对成功dispatch且仍outstanding的registry entry；不完成 canceled，保留 entry，等待已 commit callback。任意 unknown ID 不进入这条 public Call 路径。
4. callback 到达：只允许一次 Future completion；ownership 转移或 result free 完成后移除 entry。
5. `dispose()` 只在所有 callback-outstanding entry 清空后关闭 `NativeCallable`。

因此 `cancel → client.close/dispose → callback` 在 callback-committed 分支仍安全，而 accepted cancel 不会留下永久 tombstone。

## RequestBody ownership 与 copy flow

~~~text
caller Uint8List
  -- take ownership / 0 copy -->
RequestBody.takeBytes
  -- same identity -->
RequestBodyTransportAccess
  → mapper
  → NativeHttpRequestDto
  -- non-empty: exactly 1 copy per dispatch -->
FFI-owned request memory
  -- ownership move -->
Rust Vec / reqwest body
~~~

规则：

- `takeBytes` 保留输入 `Uint8List` identity；caller 构造后不得继续修改。
- `RequestBody` 不公开任何 full-body read API。
- mapper 和 DTO 传递同一个 canonical buffer。
- 同一个非空 Request 创建多个 Call 时，每次 dispatch 各做一次必要的 Dart-to-native copy，不重新构造 canonical Dart buffer；空 body 不分配、不复制。
- `RequestBody.text` 只编码一次；encoder 返回 `Uint8List` 时直接接管，generic `List<int>` 只做一次 normalization，此后 identity 不再变化。
- 非空 body 的 native allocation 如果返回 null，必须归一化为 `NexaHttpFailureKind.internal`，不能把 ABI/runtime contract violation 当成零长度或零 copy 成功。

FFI encoder 提供 internal copier seam。默认实现只调用一次当前 native view 的 `setAll`；测试注入 counter 并验证 source identity、调用次数、allocation/release 和 ownership transfer。Instrumentation 自身不得创建完整 body 副本。

## ResponseBody ownership 与 copy flow

### Internal ownership object

Decoder 不再把 native ownership 藏在裸 `List<int>` 类型中。Transport payload 使用 internal response-body owner，显式携带：

- 当前 body view；
- Dart-owned 或 native-owned storage kind；
- exactly-once release；
- one-shot ownership transfer。

~~~text
native binary result
  → decoder owner/view
  → TransportResponse
  → response mapper takes owner
  → ResponseBodyTransportAccess.adopt(owner)
  → ResponseBody private storage
~~~

Mapper 在取得 owner 前完成所有可能失败的 header/content-type/request mapping。若 ownership handoff 中途失败，必须立即 `close()` owner；不能把正常异常路径交给 finalizer。

### 两种 storage

| storage | 构造 | 首次 `bytes()` | `string()` | `close()` |
|---|---|---|---|---|
| Dart-buffered | public `ResponseBody.bytes(...)` snapshot 一次，或 string encode 一次 | 直接转移已拥有的 `Uint8List`，不再复制 | 直接 decode owned buffer | 零复制 |
| Non-empty native-adopted | decoder→mapper 中间零 copy | 恰好一次 `Uint8List` copy，然后 release | 直接 decode native view，在 `finally` release | 零复制、幂等 release |

共同规则：

- `bytes()` 返回 `Future<Uint8List>`。
- 首次 `bytes()` 或 `string()` 在开始消费时即标记 consumed。
- 第二次 `bytes()`/`string()` 抛 `StateError`。
- consume 后调用 `close()` 是无操作；重复 close 不重复 release。
- copy、decode 或 mapping 抛错都必须 exactly-once release。
- Native finalizer 只覆盖 abandoned body，不是正常成功/失败路径。
- 非空 native body 的 `bytes()` copy count 是一；零长度 body 在 decoder 阶段释放 binary result，并返回 Dart-owned empty body，不创建无意义的零字节 native copy。

内部 adoption factory允许注入 byte copier 和 decoder observer，用于证明 native view identity、copy/decode 次数与 release 次数；默认 production path 不增加 wrapper copy。

## Failure normalization

Public contract：

~~~text
NexaHttpException(
  kind: NexaHttpFailureKind,
  message: String,
  uri: Uri?,
  diagnostics: Map<String, Object?>?,
)
~~~

`diagnostics` 是非稳定、只读诊断信息。App control flow 只能依赖七值 `kind`。

### Mapping precedence

| 来源 | Public kind |
|---|---|
| cancellation terminal winner | `canceled` |
| reqwest timeout | `timeout` |
| 其他 reqwest/network execution error | `network` |
| native `invalid_request`，Dart URL/method/header/request validation | `invalidRequest` |
| native `invalid_config`/`invalid_proxy`，包括 bootstrap envelope 的 inner native code | `configuration` |
| missing carrier registration、library/symbol open、null bootstrap error、dispatch=0 | `unavailable` |
| ABI `invalid_argument`/`invalid_utf8`、`invalid_client`、non-empty request allocator返回null、serialization、malformed JSON/schema、invalid final URI、unknown native code | `internal` |

优先级：

1. 先识别 bootstrap envelope 中的 inner native code；明确的 config/proxy failure 归 `configuration`。
2. 没有可解析 native diagnostic 的 bootstrap/loader/dispatch availability failure 归 `unavailable`。
3. 格式正确但表示 ABI corruption/unknown implementation failure，或 payload 本身 malformed，归 `internal`。

新增 internal `NexaHttpFailures` normalization helper，统一构造稳定 message、URI 与 diagnostics。Native error mapper 是 native-code taxonomy 的唯一入口；loader、bootstrap、dispatch 和 decoder 在各自边界调用该 helper。

禁止 catch-all 覆盖 programmer misuse。第二次 execute、client use-after-close、第二次 body consumption 等 `StateError` 继续原样暴露。HTTP 4xx/5xx 继续返回普通 `Response`。

非空 final URL 必须严格解析；解析失败是 malformed ABI payload，归 `internal`，不能用 `Uri.tryParse` 静默变成 null。

## Generated bindings clean move

目标路径：

~~~text
packages/nexa_http/lib/src/native_bridge/nexa_http_bindings_generated.dart
~~~

同一个 slice 原子更新：

- `ffigen.yaml` output；
- package internal FFI imports；
- FFI tests 的 internal import；
- `analysis_options.yaml` exclude；
- CI regeneration/diff path；
- root ABI contract tests；
- workspace workflow/source contract tests。

旧 root file 同时删除，不创建 export stub、forwarding library 或 temporary copy。C header 与生成的函数签名不变；只有 Dart library path 改变。

## Flutter SDK contract 六面映射

| Contract 面 | 本 child 映射 | 证据 |
|---|---|---|
| Host integration surface | 宿主依赖形状不变，runtime 只 import `package:nexa_http/nexa_http.dart`；唯一执行入口是 `newCall().execute()` | positive/negative consumer fixture、root export allowlist |
| Hidden internal packages | bindings、body owner/access、FFI DTO/decoder/registry 全部位于 `lib/src/` | root file allowlist、negative analyze、legacy absence |
| Native lifecycle ownership | SDK 持有 lazy client lease、request cancellation handshake、callback handle 和 response-body release | Call/native state-machine tests、dispose/callback race、ownership tests |
| Formal configuration | 不新增 public config、environment variable、Dart define 或宿主 native 工程配置 | API diff review、README/fixture review |
| Failure reporting | runtime 只暴露七值 kind；native code/stage/message只进入 diagnostics | exhaustive normalization matrix、malformed payload tests |
| Clean-host acceptance | 本 child 更新 final-v2 consumer fixture，并运行当前 host 的 compile/build；四平台 candidate runtime gate 由后续 Native Assets、release 和 readiness child 阻断完成 | `verify-external-consumer`；下游四平台 gate |

本任务不得把当前 host build 说成四平台 release gate，也不得调用尚未由 Verification Catalog child 实现的 `verify-static`、`verify-integration` 或 `verify-release-candidate`。

## TDD 与 verification design

测试分两类：

1. Behavior tests：状态机、terminal winner、copy/release、failure mapping。
2. Source/public contract tests：root file/export allowlist、negative analyze fixture、旧 path/symbol absence、generated path consistency。

Negative fixture 以 package root import 为起点，分别证明一个禁止项无法 analyze。禁止用全仓零命中替代，因为 ADR/spec 和 negative fixture会有意记录旧 symbol。

每个行为按单个 RED → minimum GREEN → REFACTOR 推进，不先铺完所有 tests。Copy budget 使用 identity 和 injected counter，不能只比较内容相等。

## Clean cutover 与 rollback

- 本 child 同时切换 production、tests、demo、README、CHANGELOG、CI path 和 root contract。
- `packages/nexa_http/CHANGELOG.md` 是本 child 的唯一 package release-note source；不另建会漂移的临时 release note。
- 旧 symbol、旧文件和旧 path 在各自 slice GREEN 时直接删除。
- 不保留 deprecated alias、forwarding facade、fallback branch 或“双轨更安全”的中间态。
- Rollback 只允许整体 revert 本 child 或尚未合并的完整 checkpoint；不得向 production 重新加入旧 API/loader。
- 下游 task 只能在本 child 完整通过并归档后使用 final surface。

## Tradeoffs 与风险

- Cancellation 需要触及 Rust core 内部状态机，但这是关闭 callback lifetime 缺陷所必需；C ABI 签名、symbol set 和平台 adapter 不变。
- `lib/src` transport access object 是 Dart language-visible internal symbol，但显式 root allowlist、封闭 `final` body type和negative fixture共同守住支持边界。
- Public `ResponseBody.bytes(...)` 为避免 caller 后续修改会 snapshot 一次，首次消费直接转移该 owned buffer；非空 native response path仍保持 decoder→mapper 零中间 copy，首次 `bytes()` 才执行唯一 native-to-Dart copy；空 body不额外复制。
- Callback-committed request在 `dispose()` 后会延长 `NativeCallable` 生命周期直到 callback 到达；这是安全 ownership requirement，不是 fallback。
- 当前真实 native integration suite 只适用于 macOS。它需要显式 platform/tag 和 deterministic cleanup；其他平台由 CI/后续 clean-host gate覆盖，不能把 skip 记为通过。

## 未决项

无。用户已确认 clean cutover、无兼容、单次消费、复制预算、七值 failure taxonomy 和四平台 release 阻断原则；其余事实均已通过代码、ADR 和 spec 审计确定。
