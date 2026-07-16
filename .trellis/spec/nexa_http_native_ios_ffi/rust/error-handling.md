# 错误处理

iOS FFI crate 不定义新的 public error schema。错误 JSON、bootstrap error 和 result ownership 都来自 `nexa_http_native_core`。

## 规则

- C ABI 函数直接委托 `NexaHttpRuntime`。
- Apple proxy 读取失败或返回 null 时返回 `ProxySettings::default()`，不要 panic。
- 输入清洗和 URL validation 委托 `nexa_http_native_apple_proxy`；无效 proxy URL 被忽略，不应导致 client 创建失败。
- proxy source 和 ABI wiring 不写 `println!` / `eprintln!`；宿主诊断通过 core error JSON 和 Dart failure 传播。
- 不记录 proxy credential、header value、body 或 Apple proxy 原始 dictionary。
- 如需新的平台诊断字段，先定义 shared error contract，不在 iOS crate 私自增加日志开关。

## 真实例子

- `src/proxy_source.rs` 中系统 proxy 读取失败会降级为默认设置。
- `export_nexa_http_ffi!` 展开的 `nexa_http_take_last_error_json()` 直接调用 core `take_last_error_json()`。
