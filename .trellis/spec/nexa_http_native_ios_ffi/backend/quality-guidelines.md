# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，并由 Apple runner 检查最终 Mach-O symbols。
- 纯 proxy parser 必须使用 `nexa_http_native_apple_proxy` 并由其 tests 覆盖。
- iOS device/simulator target 变化必须同步 canonical target matrix、build hook、typed build script、release metadata 和 verification matrix。
- Workspace iOS targets必须由Catalog producer一次构建到共享fingerprint cache，carrier hook复用同一File；candidate通过`hooks.user_defines.nexa_http_native_ios`显式传入directory/ref。
- 最终 `.app` 必须只包含一个导出 canonical `nexa_http_*` ABI 的 payload；prepared 与 packaged framework 同一性使用 Mach-O `LC_UUID` 集合派生的 `identity_sha256`，raw SHA 分别保留审计但不要求相等。

## 禁止模式

- 不要把 iOS framework 路径写死进 Rust crate。
- 不要恢复 Podspec `preserve_paths`、carrier `Frameworks` materialization、`DynamicLibrary.process()` 或 fallback branch。
- 不要新增平台专属 HTTP 行为。
- 不要让 platform crate 读取或修改宿主 native 工程。
- 不要在 `proxy_source.rs` 重新实现共享 Apple parser 规则。

## 检查

- `cargo test -p nexa_http_native_ios_ffi`
- `cargo test -p nexa_http_native_apple_proxy`
- `fvm dart test packages/nexa_http_native_ios/test/build_hook_test.dart`
- `fvm dart test test/native_payload_identity_test.dart test/native_artifact_uniqueness_test.dart test/verification/native_asset_hook_identity_test.dart`
- Catalog `verify-integration --execution apple-macos` 完整 suite。
