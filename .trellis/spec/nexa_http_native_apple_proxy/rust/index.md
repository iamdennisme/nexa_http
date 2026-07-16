# nexa_http_native_apple_proxy Rust 规范

> `native/nexa_http_native_apple_proxy` 是 iOS/macOS 共用的纯 Rust Apple proxy parser。它接收平台 crate 已读取的原始值，返回 `nexa_http_native_core::platform::ProxySettings`。

## 规范索引

| 规范 | 说明 | 状态 |
|------|------|------|
| [Apple proxy parser 契约](./proxy-parser-contract.md) | 输入结构、解析行为、平台边界和测试要求 | 已填充 |

## Pre-Development Checklist

- [ ] 阅读 `docs/adr/0004-platform-owned-proxy-runtime-state.md`，保持平台 proxy source 所有权不变。
- [ ] 修改输入字段或解析行为时同步 iOS/macOS adapter 和本 crate 的 parser tests。
- [ ] 不在本 crate 引入 CoreFoundation、SystemConfiguration、C ABI、runtime state 或 Flutter artifact 逻辑。
- [ ] 不新增 host-visible package、配置或动态库产物。

## Quality Check

- [ ] `cargo fmt --all --check` 通过。
- [ ] `cargo clippy --no-deps -p nexa_http_native_apple_proxy --all-targets -- -D warnings` 通过。
- [ ] `cargo test -p nexa_http_native_apple_proxy` 通过。
- [ ] `cargo test -p nexa_http_native_macos_ffi` 和 `cargo test -p nexa_http_native_ios_ffi` 通过。
- [ ] 触达 Rust dependency/package 边界时，Catalog `verify-integration` 的 Apple execution row 通过。
