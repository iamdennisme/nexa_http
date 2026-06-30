# 错误处理

native core 的错误边界分两类：Rust 内部 `Result` / `NativeError`，以及跨 FFI 暴露给 Dart 的 JSON error。

## 错误类型

- `NativeError` 是 Rust 内部构建错误的 helper，字段包括 `code`、`message`、`status_code`、`is_timeout`、`uri`、`details`。
- `NativeHttpError` 是可序列化结构，使用 `serde(rename_all = "snake_case")`，由 Dart decoder 消费。
- bootstrap 阶段错误通过 `store_bootstrap_error()` 写入 `LAST_ERROR_JSON`，Dart 侧通过 `nexa_http_take_last_error_json()` 读取。

## 传播模式

- HTTP 执行错误必须转换成结构化 `NativeHttpError`，不要跨 FFI 传播 panic 文本。
- FFI callback 结果使用 `NexaHttpBinaryResult`；成功和失败都必须让 Dart 侧能释放 owned body、headers、final URL 和 error JSON。
- `CString::new()` 只可用于内部构造已知无 NUL 的字符串或测试辅助；来自请求/headers 的输入必须走 parser/decoder 并返回错误。

## 常见错误

- 不要在 FFI 入口对宿主输入 `unwrap()`，这会把可恢复 SDK 错误变成进程崩溃。
- 不要新增只有 `message` 的错误；至少要保留 `code`，需要定位宿主问题时放入 `details`。
- 不要在 platform crate 中重新定义错误 JSON schema；platform crate 应调用 core runtime 或复用 core FFI 类型。

## 真实例子

- `native/nexa_http_native_core/src/api/error.rs`：定义 `NativeError` 和 `NativeHttpError`。
- `native/nexa_http_native_core/src/api/ffi.rs`：`store_bootstrap_error()` 把 bootstrap 失败包装成稳定 JSON。
- `native/nexa_http_native_core/src/runtime/executor.rs`：执行、取消和 callback 路径集中转换请求错误。
