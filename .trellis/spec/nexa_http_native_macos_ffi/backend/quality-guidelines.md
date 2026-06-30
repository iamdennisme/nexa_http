# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`，保证动态库产物和 Rust tests 都可用。
- 所有 C ABI export 使用和其他平台一致的 `nexa_http_*` 函数名。
- Proxy 解析 helper 必须可测试；平台系统调用包在 `#[cfg(target_os = "macos")]` 模块中。

## 禁止模式

- 不要把 macOS build artifact 路径写死进 Rust crate；路径由 Dart hook 和 CocoaPods 管理。
- 不要新增平台专属 request/response 行为；HTTP 行为属于 shared core。

## 检查

- `cargo test -p nexa_http_native_macos_ffi`
- `fvm dart test packages/nexa_http_native_macos/test/build_hook_test.dart`
