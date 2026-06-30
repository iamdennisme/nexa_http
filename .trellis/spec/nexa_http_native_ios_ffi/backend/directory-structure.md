# 目录结构

## 目录布局

```text
packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   └── proxy_source.rs
└── tests/proxy_settings.rs
```

## 模块职责

- `src/lib.rs` 只做 C ABI export 和 runtime wiring，复用 `nexa_http_native_core::runtime::NexaHttpRuntime`。
- `src/proxy_source.rs` 实现 `IosProxySource`，通过 Apple SystemConfiguration 字段读取 iOS/macOS family proxy 设置。
- `tests/proxy_settings.rs` 验证 Apple proxy 字段解析、bypass 去重和 refresh mode。

## 禁止模式

- 不要在 iOS crate 中复制 core request/response/runtime executor。
- 不要在 Rust FFI crate 中处理 release asset 下载、workspace 查找或 pub-cache 判断。
- 不要在 iOS crate 中引入宿主 Podfile、Xcode project 或 Flutter plugin registration 逻辑。

## 真实例子

- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs`：导出统一 `nexa_http_*` ABI。
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/proxy_source.rs`：实现 `IosProxySource` 和 Apple proxy parser。
