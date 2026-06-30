# 日志规范

native core 当前不使用 `tracing`、`log` 或 stdout/stderr 作为运行时诊断通道。宿主可见错误通过结构化 error JSON 返回给 Dart。

## 规则

- 不要在 library/runtime 代码中新增 `println!`、`eprintln!` 或临时 debug 输出。
- 需要暴露给宿主的问题必须进入 `NativeHttpError.details` 或 Dart 层异常，而不是写 native 日志。
- 测试代码可以使用 panic/expect 说明测试前提，但生产路径不能依赖 panic 传递错误。
- 不要记录 URL body、header value、token、cookie 或 proxy credential。

## 应该记录在哪里

- Bootstrap 失败：`store_bootstrap_error()` 的 JSON details。
- HTTP 请求失败：`NativeHttpError` 的 `code`、`message`、`status_code`、`is_timeout`、`uri`。
- Artifact/build-hook 失败：Dart `nexa_http_native_internal` 的 artifact exception，不在 Rust core 打日志。

## 真实例子

- `native/nexa_http_native_core/src/api/ffi.rs`：`LAST_ERROR_JSON` 是 bootstrap 失败的宿主可读通道。
- `packages/nexa_http/lib/src/data/mappers/native_http_error_mapper.dart`：Dart 侧把 native error DTO 映射成 public exception。
