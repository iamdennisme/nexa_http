# 目录结构

## 目录布局

```text
packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   └── proxy_source.rs
└── tests/proxy_settings.rs
```

## 模块职责

- `src/lib.rs` 只定义 macOS `RUNTIME` 和 runtime wiring，并调用 core `export_nexa_http_ffi!` 生成统一 C ABI exports。
- `src/proxy_source.rs` 实现 `MacosProxySource`，通过 `SCDynamicStoreCopyProxies` 读取 raw macOS proxy 值，再委托 `nexa_http_native_apple_proxy`。
- `tests/proxy_settings.rs` 验证 raw-value adapter wiring、runtime state 和 refresh mode；纯解析规则由共享 parser tests 验证。

## 禁止模式

- 不要在 macOS crate 中复制 request/response/client registry/runtime executor 逻辑。
- 不要在 macOS crate 中复制 Apple proxy URL normalization、值清洗或 bypass canonicalization。
- 不要在 Rust FFI crate 中处理 release asset 下载、workspace 查找或 pub-cache 判断；这些属于 Dart build hook / internal package。
- 不要改变 `nexa_http_*` C ABI 函数名，除非同步所有平台 crate、Dart bindings 和 tests。

## 真实例子

- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs`：保留 construction-boundary runtime 并调用共享 ABI export macro。
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/proxy_source.rs`：平台专属 proxy source。
- `native/nexa_http_native_apple_proxy/src/lib.rs`：iOS/macOS 共用的纯 Apple proxy parser。
