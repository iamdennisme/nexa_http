# 错误处理

平台 FFI crate 不定义新的 public error schema。错误 JSON、bootstrap error 和 result ownership 都来自 `nexa_http_native_core`。

## 规则

- `src/lib.rs` 的 C ABI 函数应直接委托 `NexaHttpRuntime`，不要在每个平台包重新包装错误 JSON。
- 非 Android 目标调用当前 proxy 读取时返回 `ProxySettings::default()`，用于本机单元测试。
- Android `getprop` 执行失败、退出非零、输出不是 UTF-8 或清洗后为空时忽略该字段，不要 panic。
- 无效 proxy URL 被忽略而不是暴露成请求失败；URL 规范化只接受 `http`、`https`、`socks4`、`socks4a`、`socks5`、`socks5h`。
- 端口解析失败时使用该协议默认端口，而不是让整个 proxy source 失败。

## 真实例子

- `src/proxy_source.rs` 中 `current_proxy_settings()` 在 `#[cfg(not(target_os = "android"))]` 下返回默认设置。
- `src/proxy_source.rs` 中 `getprop()` 使用 `Command::new("getprop").arg(key).output().ok()?`，失败直接返回 `None`。
- `export_nexa_http_ffi!` 展开的 `nexa_http_take_last_error_json()` 直接调用 core `take_last_error_json()`。
