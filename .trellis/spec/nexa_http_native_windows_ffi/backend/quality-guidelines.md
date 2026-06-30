# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 C ABI export 与其他平台保持同名同签名。
- Windows x64 target 变化必须同步 target matrix、build hook、CMake 和 release workflow。

## 禁止模式

- 不要把 DLL 复制路径写死进 Rust crate。
- 不要新增平台专属 HTTP 行为。
- 不要在 Rust crate 中尝试修改宿主 Windows project。

## 检查

- `cargo test -p nexa_http_native_windows_ffi`
- `fvm dart test packages/nexa_http_native_windows/test/build_hook_test.dart`
