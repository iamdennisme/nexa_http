# Decompose Rust executor

## Goal

在保持统一 C ABI、runtime behavior、error schema、cancellation linearization 和 native ownership 不变的前提下，把 `native/nexa_http_native_core/src/runtime/executor.rs` 从多职责文件收敛为 runtime facade/orchestrator，并为 client registry、inflight state、HTTP execution、FFI decode 和 FFI result ownership建立可独立验证的内部模块边界。

## Background

- `executor.rs` 当前约 1408 行，同时定义 `NexaHttpRuntime`、client map/generation refresh、inflight cancellation、raw FFI decode、reqwest execution/error mapping、binary result encode/free 和全部单元测试。
- `runtime/client_registry.rs` 当前只保存 `ClientEntry` 数据结构，registry mutex、ID 分配、client creation/refresh 仍在 executor，边界较浅。
- `api/request.rs` 和 `api/response.rs` 已拥有 Rust request/response/owned-body model；raw pointer decode 和 `NexaHttpBinaryResult` buffer ownership应分别靠近 API 边界，而不是 HTTP orchestrator。
- `api/ffi_exports.rs` 是九个 public C ABI wrapper 的唯一来源；platform crates只构造 `NexaHttpRuntime<ManagedProxyState<_>>`，不得感知内部拆分。
- Proxy normalization 已在 `e2017b8` 集中到 core primitives；本任务不再调整其规则。

## Dependencies

- 以已发布并通过四平台验证的 `v2.0.1` 为行为基线。
- 依赖已完成的 `centralize-proxy-normalization`，以当前 `platform`/error/request/response contracts 为固定输入。

## Requirements

### R1. Preserve the external runtime contract

- `NexaHttpRuntime<P>` 名称、generic bound和公开方法签名保持不变。
- `export_nexa_http_ffi!`、canonical 九个 `nexa_http_*` symbols、C header、generated Dart bindings和platform FFI wiring不变。
- Bootstrap error stage、`NativeHttpError` shape、callback delivery和body/header/final-url/error free ownership不变。

### R2. Establish one owner per responsibility

- `runtime/executor.rs` 只拥有 public runtime facade、Tokio spawn/semaphore orchestration和跨模块调用顺序。
- `runtime/client_registry.rs` 拥有 client map、client ID、client creation、close、proxy generation refresh/rebuild和steady-state fast path。
- `runtime/inflight.rs` 拥有 request key、Pending/CanceledPending/Active/CallbackCommitted state machine、abort和callback commit linearization。
- `runtime/request_execution.rs` 拥有 reqwest method/header/body/timeout application、raw response projection和network/timeout cause-chain mapping。
- `api/ffi_decode.rs` 拥有 raw client config/request/header/string decode和request-body adoption/copy semantics。
- `api/ffi_result.rs` 拥有 success/error `NexaHttpBinaryResult` construction、CString/header buffer allocation和完整 result free。
- `api/ffi_types.rs` 拥有稳定 C ABI layout/callback alias；`api::ffi` 仅从该 leaf module 重导出既有 public Rust path。

### R3. Preserve concurrency and ownership behavior

- Accepted cancel (`1`) 继续保证callback不会发生；Callback Commit先赢时cancel返回 `0` 且callback恰好到达一次。
- Pending task在abort handle安装前被取消时继续使用 `CanceledPending`，安装后清理且不callback。
- Proxy generation不变时不读取platform state；变化时最多按现有循环刷新，失败重建后下一请求继续重试。
- Owned request body仍被adopt而不复制；borrowed body仍复制；response bytes仍只保留一个native owner和一个free路径。

### R4. Clean architectural cutover

- 被迁移的类型和函数从 `executor.rs` 删除，不保留 forwarding helpers、旧/新双轨或 re-export chain。
- 内部模块使用 `pub(crate)`/`pub(super)` 最小可见性；platform crates仍只依赖 `runtime::NexaHttpRuntime` 和 `ManagedProxyState`。
- 不新增 crate、feature、runtime config、logging或host-visible integration surface。

### R5. Verification and module contracts

- 保留并重定位现有 cancellation、client refresh、error cause-chain、header decode和body ownership tests。
- 新增 module-boundary source contract test，拒绝 `executor.rs` 重新定义 decode/result/client-entry/inflight-state/reqwest-mapping职责。
- Core focused tests、workspace Rust fmt/clippy/test、ABI source contract和Apple integration execution通过。

## Acceptance Criteria

- [x] AC1 (`R2`, `R4`): `executor.rs` production code只保留 facade/orchestration，不再定义 registry map、inflight enum、FFI decode/result buffers或reqwest error mapping。
- [x] AC2 (`R1`): `NexaHttpRuntime` public methods、FFI macro、header/bindings和platform crate sources没有行为或签名变化。
- [x] AC3 (`R3`): cancellation、proxy refresh、request/response ownership、headers和error mapping回归全部通过。
- [x] AC4 (`R5`): module boundary contract能定位每个责任owner并拒绝回流。
- [x] AC5 (`R4`): 搜索不到旧 helper、forwarding wrapper或新旧双轨；新模块之间无循环依赖。
- [x] AC6 (`R5`): `cargo fmt`、workspace strict Clippy、workspace tests、ABI contract和Apple integration gate通过。
- [x] AC7: specs准确记录新的 runtime/api 模块职责。

## Out of Scope

- 修改 public Dart API、C ABI、error taxonomy或proxy normalization。
- 改变 cancellation/refresh/timeout/retry策略。
- 性能优化、增加新HTTP能力或改变请求/响应copy budget。
- 修改 artifact packaging、carrier hook、target matrix或release transaction。
