# 日志规范

Android FFI crate 默认不写运行时日志。

## 规则

- 不要在 proxy 读取或 ABI export 中新增 `println!` / `eprintln!`。
- `getprop` 读取失败时返回默认或部分 proxy 设置，由请求行为和 Dart error 负责暴露可见问题。
- 不要记录 proxy credential、header value、URL body、系统属性原始 dump 或命令输出。
- 如果未来确实需要诊断日志，必须先在 shared core 或 Dart 层设计统一开关，不能在单个平台 crate 私自输出。

## 真实例子

- `src/proxy_source.rs` 只返回 `ProxySettings`，不输出诊断文本。
- `src/lib.rs` 只暴露 ABI 并委托 `NexaHttpRuntime`，不打印请求或错误内容。
