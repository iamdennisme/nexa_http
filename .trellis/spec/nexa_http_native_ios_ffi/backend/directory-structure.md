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
- `src/proxy_source.rs` 实现 `IosProxySource`，读取 raw Apple SystemConfiguration 值，再委托 `nexa_http_native_apple_proxy`。
- `tests/proxy_settings.rs` 验证 raw-value adapter wiring、runtime state 和 refresh mode；纯解析规则由共享 parser tests 验证。

## 禁止模式

- 不要在 iOS crate 中复制 core request/response/runtime executor。
- 不要在 iOS crate 中复制 Apple proxy URL normalization、值清洗或 bypass canonicalization。
- 不要在 Rust FFI crate 中处理 release asset 下载、workspace 查找或 pub-cache 判断。
- 不要在 iOS crate 中引入宿主 Podfile、Xcode project 或 Flutter plugin registration 逻辑。

## 真实例子

- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs`：导出统一 `nexa_http_*` ABI。
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/proxy_source.rs`：实现 `IosProxySource` 和 SystemConfiguration adapter。
- `native/nexa_http_native_apple_proxy/src/lib.rs`：iOS/macOS 共用的纯 Apple proxy parser。
