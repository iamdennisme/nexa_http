# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，并由 Windows runner 检查最终 PE exports。
- Windows x64 target 变化必须同步 canonical target matrix、build hook、typed build script、release metadata 和 verification matrix。
- 最终 runner distribution 必须只包含一个导出 canonical `nexa_http_*` ABI 的 payload；Windows `identity_sha256` 等于 packaged raw SHA。

## 禁止模式

- 不要把 DLL 复制路径写死进 Rust crate。
- 不要恢复 CMake `bundled_libraries` copy、carrier `Libraries` materialization、DLL basename manual loader 或 fallback branch。
- 不要新增平台专属 HTTP 行为。
- 不要在 Rust crate 中尝试修改宿主 Windows project。

## 检查

- `cargo test -p nexa_http_native_windows_ffi`
- `fvm dart test packages/nexa_http_native_windows/test/build_hook_test.dart`
- `fvm dart test test/native_artifact_uniqueness_test.dart test/verification/native_asset_hook_identity_test.dart`
- Catalog `verify-integration --execution windows-x64` 完整 suite。
