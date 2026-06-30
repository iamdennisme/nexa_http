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

- `src/lib.rs` 只做 C ABI export 和 runtime wiring，复用 `nexa_http_native_core::runtime::NexaHttpRuntime`。
- `src/proxy_source.rs` 实现 `MacosProxySource`，通过 `SCDynamicStoreCopyProxies` 读取 macOS proxy 设置。
- `tests/proxy_settings.rs` 验证 Apple proxy 字段解析、bypass 去重和 refresh mode。

## 禁止模式

- 不要在 macOS crate 中复制 request/response/client registry/runtime executor 逻辑。
- 不要在 Rust FFI crate 中处理 release asset 下载、workspace 查找或 pub-cache 判断；这些属于 Dart build hook / internal package。
- 不要改变 `nexa_http_*` C ABI 函数名，除非同步所有平台 crate、Dart bindings 和 tests。

## 真实例子

- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs`：统一导出 `nexa_http_client_create`、`nexa_http_client_execute_async` 等 ABI。
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/proxy_source.rs`：平台专属 proxy source。
