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
│   │   ├── ffi_exports.rs
│   │   ├── request.rs
│   │   └── response.rs
│   ├── platform/
│   │   ├── capabilities.rs
│   │   ├── proxy.rs
│   │   └── source.rs
│   ├── runtime/
│   │   ├── client_registry.rs
│   │   ├── executor.rs
│   │   ├── managed_proxy_state.rs
│   │   └── tokio_runtime.rs
│   └── lib.rs
└── tests/
```

## 模块职责

- `api/ffi.rs` 定义 C ABI 可见的 struct、callback type、string free 和测试辅助入口，例如 `NexaHttpRequestArgs`、`NexaHttpBinaryResult`、`nexa_http_string_free`。
- `api/ffi_exports.rs` 定义 `export_nexa_http_ffi!`，集中生成所有平台一致的九个 public C ABI wrappers；平台 crate 只提供自己的 static runtime 和 state type。
- `api/request.rs` / `api/response.rs` 负责把 FFI pointer/length 读成 core 内部请求/响应模型，并维护 native-owned body 的释放规则。
- `api/error.rs` 定义 `NativeError` 与可序列化的 `NativeHttpError`。跨 FFI 的错误 JSON 必须从这里的模型出发。
- `runtime/executor.rs` 是 HTTP client、request dispatch、cancellation、callback 和 result free 的主要实现位置。
- `runtime/managed_proxy_state.rs` 负责 proxy state 刷新策略，调用 `platform::ProxyConfigSource`。
- `platform/` 只定义跨平台抽象和 shared proxy 匹配逻辑，不读取具体 OS 配置。

## 命名约定

- C ABI 可见类型使用 `NexaHttp*` 前缀，函数使用 `nexa_http_*` snake case。
- Rust 内部错误类型用 `Native*` 前缀，避免和 Dart API 的 public `NexaHttpException` 混淆。
- FFI pointer 字段必须显式成对出现：`*_ptr` + `*_len`；有 ownership 的字段必须有 owner 或 free 函数。

## 禁止模式

- 不要在 core crate 中读取平台 registry、CoreFoundation、Android property 或 Windows registry；这些属于 platform FFI crate。
- 不要在 core crate 中搜索 workspace、pub-cache、packaged artifact 或环境变量路径；artifact 选择属于 Dart build hook / carrier package。
- 不要把 Dart DTO shape 复制进 Rust 文档字符串；真实边界是 FFI struct 和 JSON error contract。

## 真实例子

- `native/nexa_http_native_core/src/runtime/executor.rs`：集中管理 client registry、in-flight request、callback 和 result free。
- `native/nexa_http_native_core/src/platform/source.rs`：定义 `ProxyConfigSource` 与 `RefreshMode`，平台 crate 只实现该 trait。
- `native/nexa_http_native_core/tests/runtime_smoke.rs`：覆盖 FFI runtime smoke、callback 和 request/response 行为。
