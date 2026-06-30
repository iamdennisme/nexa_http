# 日志规范

Windows FFI crate 默认不写运行时日志。

## 规则

- 不要在 registry 读取或 ABI export 中新增 `println!` / `eprintln!`。
- Registry 读取失败时返回默认设置。
- 不要记录 proxy credential、header value、URL body 或 registry 原始 dump。
