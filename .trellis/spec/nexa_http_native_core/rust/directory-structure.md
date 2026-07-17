# 目录结构

`native/nexa_http_native_core` 是共享 Rust core，只产出 `rlib`，不直接产出平台动态库。平台动态库由 `packages/nexa_http_native_<platform>/native/*_ffi` crate 包装。

## 目录布局

```text
native/nexa_http_native_core/
├── include/nexa_http_native.h
├── src/
│   ├── api/
│   │   ├── error.rs
│   │   ├── ffi.rs
│   │   ├── ffi_decode.rs
│   │   ├── ffi_exports.rs
│   │   ├── ffi_result.rs
│   │   ├── ffi_types.rs
│   │   ├── request.rs
│   │   └── response.rs
│   ├── platform/
│   │   ├── capabilities.rs
│   │   ├── proxy.rs
│   │   ├── proxy_normalization.rs
│   │   └── source.rs
│   ├── runtime/
│   │   ├── client_registry.rs
│   │   ├── executor.rs + executor/tests.rs
│   │   ├── inflight.rs
│   │   ├── managed_proxy_state.rs
│   │   ├── request_execution.rs
│   │   └── tokio_runtime.rs
│   └── lib.rs
└── tests/
```

## 模块职责

- `api/ffi_types.rs` 是 C ABI layout 与 callback alias 的 leaf owner；`api/ffi.rs` 重导出同名类型以保持既有 Rust path，并只拥有 bootstrap error、string free 和测试辅助入口。
- `api/ffi_decode.rs` 是 raw client config/request/header/string pointer decode 的唯一 owner；owned request body 在此 adopt，borrowed body 在此复制。
- `api/ffi_result.rs` 是 success/error `NexaHttpBinaryResult` 构造与完整 result free 的唯一 owner；headers、final URL、error JSON 和 response body 都从同一入口释放。
- `api/ffi_exports.rs` 定义 `export_nexa_http_ffi!`，集中生成所有平台一致的九个 public C ABI wrappers；平台 crate 只提供自己的 static runtime 和 state type。
- `api/request.rs` / `api/response.rs` 定义 core 内部请求/响应模型及 native-owned body 的底层 owner；它们不解析完整 FFI args，也不构造 binary result。
- `api/error.rs` 定义 `NativeError` 与可序列化的 `NativeHttpError`。跨 FFI 的错误 JSON 必须从这里的模型出发。
- `runtime/executor.rs` 只保留 `NexaHttpRuntime` facade、Tokio spawn/semaphore 和跨 owner 调用顺序；facade 行为测试位于 `runtime/executor/tests.rs`。
- `runtime/client_registry.rs` 拥有 client map/ID、client build/close、proxy generation/signature optimistic refresh 和 steady-state fast path。
- `runtime/inflight.rs` 拥有 request key 与 `Pending`/`CanceledPending`/`Active`/`CallbackCommitted` 状态机；cancel、abort handle 安装、callback commit 与 guard cleanup 必须通过其 command-shaped API 完成。
- `runtime/request_execution.rs` 拥有 reqwest method/header/body/timeout application、raw response projection和 network/timeout cause-chain mapping。
- `runtime/managed_proxy_state.rs` 负责 proxy state 刷新策略，调用 `platform::ProxyConfigSource`。
- `platform/` 只定义跨平台抽象、shared proxy normalization/matching，不读取具体 OS 配置。
- `platform/proxy_normalization.rs` 是 workspace-internal pure primitive 的唯一实现点：value cleanup、supported-scheme URL normalization、delimited bypass splitting，以及已分词 bypass canonicalization。
- `platform/proxy.rs` 负责 env fallback、snapshot、matching 和 reqwest application；必须调用 `proxy_normalization`，不能重新实现其规则。

## 命名约定

- C ABI 可见类型使用 `NexaHttp*` 前缀，函数使用 `nexa_http_*` snake case。
- Rust 内部错误类型用 `Native*` 前缀，避免和 Dart API 的 public `NexaHttpException` 混淆。
- FFI pointer 字段必须显式成对出现：`*_ptr` + `*_len`；有 ownership 的字段必须有 owner 或 free 函数。

## 禁止模式

- 不要在 core crate 中读取平台 registry、CoreFoundation、Android property 或 Windows registry；这些属于 platform FFI crate。
- 不要在 core crate 中搜索 workspace、pub-cache、packaged artifact 或环境变量路径；artifact 选择属于 Dart build hook / carrier package。
- 不要把 Dart DTO shape 复制进 Rust 文档字符串；真实边界是 FFI struct 和 JSON error contract。

## 状态与持久化边界

- 本 crate 不引入数据库、ORM、migration、文件数据库或后台持久化缓存。
- client registry、in-flight request、proxy snapshot 和 Tokio runtime 都是进程内状态，由 `runtime/` 中的明确 owner 管理。
- 跨请求共享状态必须放入可测试的 runtime struct，例如 `ClientRegistry` 或 `ManagedProxyState`，并明确创建、刷新和释放生命周期。
- child runtime module不得 import `runtime::executor`；`inflight` 不依赖 API/platform/reqwest，`request_execution` 不依赖 registry/inflight/FFI。
- `ffi_result` 必须依赖 `ffi_types` leaf，不得反向依赖 `ffi`；否则 `ffi` 调用统一 free 时会形成双向 module dependency。
- native artifact manifest、release metadata 和 platform package 配置属于 Flutter SDK 层，不得写入 core 本地存储。
- 测试使用 in-memory fake、fixture server 或测试自己拥有的临时目录，不为测试引入 production 持久化路径。
- 如果未来需要持久化，必须先通过 task 与 ADR 定义数据所有权、清理策略、隐私影响和跨平台路径。

## 真实例子

- `native/nexa_http_native_core/src/runtime/executor.rs`：只编排 decode、registry、inflight、request execution、result encode 和 callback 顺序。
- `native/nexa_http_native_core/tests/runtime_module_boundaries.rs`：拒绝责任回流与内部 module dependency cycle。
- `native/nexa_http_native_core/src/platform/source.rs`：定义 `ProxyConfigSource` 与 `RefreshMode`，平台 crate 只实现该 trait。
- `native/nexa_http_native_core/src/platform/proxy_normalization.rs`：定义平台 crate 共用的纯 proxy normalization primitives；不读取 OS、不拥有 refresh state。
- `native/nexa_http_native_core/tests/runtime_smoke.rs`：覆盖 FFI runtime smoke、callback 和 request/response 行为。
- `native/nexa_http_native_core/tests/proxy_runtime.rs`：用测试 source 验证进程内 proxy state，不依赖数据库。
