# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，并由 Windows runner 检查最终 PE exports。
- Windows x64 target 变化必须同步 target matrix、build hook、CMake 和 release workflow。

## 禁止模式

- 不要把 DLL 复制路径写死进 Rust crate。
- 不要新增平台专属 HTTP 行为。
- 不要在 Rust crate 中尝试修改宿主 Windows project。

## 检查

- `cargo test -p nexa_http_native_windows_ffi`
- `fvm dart test packages/nexa_http_native_windows/test/build_hook_test.dart`
