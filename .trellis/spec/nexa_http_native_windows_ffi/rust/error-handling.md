# 错误处理

Windows FFI crate 不定义新的 public error schema。错误 JSON、bootstrap error 和 result ownership 都来自 `nexa_http_native_core`。

## 规则

- C ABI 函数直接委托 `NexaHttpRuntime`。
- Registry key 不存在、`ProxyEnable` 关闭或 `ProxyServer` 缺失时返回默认 proxy 设置。
- 无效 proxy URL 被忽略，不应导致 client 创建失败。
- registry adapter 和 ABI wiring 不写 `println!` / `eprintln!`；宿主诊断通过 core error JSON 和 Dart failure 传播。
- 不记录 proxy credential、header value、body 或 registry 原始 dump。
- 如需新的平台诊断字段，先定义 shared error contract，不在 Windows crate 私自增加日志开关。

## 真实例子

- `src/proxy_source.rs` 中 `open_subkey_with_flags` 失败时返回 `ProxySettings::default()`。
