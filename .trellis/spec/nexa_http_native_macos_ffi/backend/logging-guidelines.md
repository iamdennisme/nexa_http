# 日志规范

macOS FFI crate 默认不写运行时日志。

## 规则

- 不要在 proxy 读取或 ABI export 中新增 `println!` / `eprintln!`。
- 系统 proxy 读取失败时返回默认设置，由请求行为和 Dart error 负责暴露可见问题。
- 不要记录 proxy credential、header value、URL body 或系统 registry/dynamic store 原始 dump。

## 真实例子

- `src/proxy_source.rs` 只返回 `ProxySettings`，不输出诊断文本。
