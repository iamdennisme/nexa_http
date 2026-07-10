# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`，保证动态库产物和 Rust tests 都可用。
- 所有 C ABI export 使用和其他平台一致的 `nexa_http_*` 函数名。
- 平台系统调用包在 `#[cfg(target_os = "macos")]` 模块中；纯 proxy parser 必须使用 `nexa_http_native_apple_proxy` 并由其 tests 覆盖。

## 禁止模式

- 不要把 macOS build artifact 路径写死进 Rust crate；路径由 Dart hook 和 CocoaPods 管理。
- 不要新增平台专属 request/response 行为；HTTP 行为属于 shared core。
- 不要在 `proxy_source.rs` 重新实现共享 Apple parser 规则。

## 检查

- `cargo test -p nexa_http_native_macos_ffi`
- `cargo test -p nexa_http_native_apple_proxy`
- `fvm dart test packages/nexa_http_native_macos/test/build_hook_test.dart`
