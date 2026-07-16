# 错误处理

平台 FFI crate 不定义新的 public error schema。错误 JSON、bootstrap error 和 result ownership 都来自 `nexa_http_native_core`。

## 规则

- `src/lib.rs` 的 C ABI 函数应直接委托 `NexaHttpRuntime`，不要在每个平台包重新包装错误 JSON。
- macOS proxy 读取失败或系统 API 返回 null 时返回 `ProxySettings::default()`，不要 panic。
- 输入清洗和 URL validation 委托 `nexa_http_native_apple_proxy`；无效 proxy URL 被忽略而不是暴露成请求失败。
- proxy source 和 ABI wiring 不写 `println!` / `eprintln!`；宿主诊断通过 core error JSON 和 Dart failure 传播。
- 不记录 proxy credential、header value、body 或 SystemConfiguration 原始 dictionary。
- 如需新的平台诊断字段，先定义 shared error contract，不在 macOS crate 私自增加日志开关。

## 真实例子

- `src/proxy_source.rs` 中 `SCDynamicStoreCopyProxies` 返回 null 时降级为 `ProxySettings::default()`。
- `export_nexa_http_ffi!` 展开的 `nexa_http_take_last_error_json()` 直接调用 core `take_last_error_json()`。
