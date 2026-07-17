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

## 诊断通道与敏感信息

- native library/runtime 不使用 `println!`、`eprintln!`、`tracing` 或 `log` 作为宿主诊断通道。
- 宿主可见问题必须进入 `NativeHttpError`、bootstrap error JSON 或 Dart 层异常；artifact/build-hook 失败由 `nexa_http_native_internal` 的结构化异常负责。
- 生产路径不得依赖 panic 传递可恢复错误。测试可以用 `expect` 说明测试前提。
- 不记录 request/response body、header value、token、cookie、proxy credential 或原始系统配置 dump。
- 新增诊断信息时扩展稳定错误 envelope 的 `details`，并同步 Dart mapper 与验证 fixture；不得让单个平台私自增加 stdout/stderr 开关。

## 真实例子

- `native/nexa_http_native_core/src/api/error.rs`：定义 `NativeError` 和 `NativeHttpError`。
- `native/nexa_http_native_core/src/api/ffi.rs`：`store_bootstrap_error()` 把 bootstrap 失败包装成稳定 JSON。
- `native/nexa_http_native_core/src/runtime/request_execution.rs`：集中转换 reqwest network/timeout 错误并保留 cause chain。
- `native/nexa_http_native_core/src/runtime/executor.rs`：保持 bootstrap stage、异步 decode error callback 和最终 result encode 顺序。

## Scenario: Transport failure 保留跨 FFI cause chain

### 1. Scope / Trigger

- Trigger：修改`reqwest::Error`映射、network/timeout错误、`NativeHttpError.details`、Dart failure diagnostics或clean-host runtime失败报告。

### 2. Signatures

- Rust映射：`runtime/request_execution.rs` 内部的 `map_reqwest_error(error: reqwest::Error, url: &str) -> NativeError`。
- Native details：`details.source_chain: String`，按最外层到最内层使用` <- `连接`std::error::Error::source()`。
- Fixture failure：`NEXA_HTTP_RUNTIME_FAILURE {"type":...,"message":...,"kind":...,"uri":...,"diagnostics":...}`。

### 3. Contracts

- Network与timeout错误保留稳定`code/message/uri/is_timeout`，同时把非空底层source chain放入`details.source_chain`。
- source chain只用于结构化诊断，不改变failure kind、重试策略或public API。
- Dart `NativeHttpErrorMapper`继续透传native details；clean-host fixture对`NexaHttpException`输出kind、uri和diagnostics，不能只输出泛化`toString()`。
- Native core不直接写日志；诊断仍通过FFI error JSON到Dart，再由verification fixture输出。

### 4. Validation & Error Matrix

- reqwest有source chain -> `details.source_chain`非空并跨FFI保留。
- reqwest无source -> 不伪造cause字段，保留原message/code/uri。
- timeout -> `code=timeout`、`is_timeout=true`并可同时带source chain。
- network -> `code=network`、`is_timeout=false`并可同时带source chain。
- fixture收到非`NexaHttpException` -> 输出type/message，不伪造kind/diagnostics。

### 5. Good/Base/Bad Cases

- Good：Android candidate失败报告包含`network`和`source_chain=...os error...`，可区分权限、拒绝连接、无路由或proxy连接失败。
- Base：上游error没有source，仍返回现有稳定network/timeout envelope。
- Bad：只保留`error sending request for url (...)`，导致不同transport根因在release gate中不可区分。

### 6. Tests Required

- Rust unit使用已关闭的本地TCP端口制造真实reqwest连接错误，断言network code、uri与非空`details.source_chain`。
- Dart fixture source test断言typed exception failure JSON包含kind和diagnostics，并先于stderr输出。
- `cargo test -p nexa_http_native_core`、`fvm dart test test/verification`与四平台release-candidate gate。

### 7. Wrong vs Correct

#### Wrong

```rust
NativeError::new("network", error.to_string()).with_uri(url)
```

#### Correct

```rust
let details = HashMap::from([("source_chain".to_string(), source_chain)]);
NativeError::new("network", error.to_string())
    .with_uri(url)
    .with_details(details)
```
