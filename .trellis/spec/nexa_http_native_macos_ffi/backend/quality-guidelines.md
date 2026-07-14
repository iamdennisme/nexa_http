# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`，保证动态库产物和 Rust tests 都可用。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，并由 Apple runner 检查最终 Mach-O symbols。
- 平台系统调用包在 `#[cfg(target_os = "macos")]` 模块中；纯 proxy parser 必须使用 `nexa_http_native_apple_proxy` 并由其 tests 覆盖。
- arm64/x64必须由canonical target matrix显式驱动各自Rust target。Workspace输出使用唯一release filename区分的共享fingerprint cache；release/candidate使用Flutter hook target-scoped directory。
- 最终 `.app` 必须只包含一个导出 canonical `nexa_http_*` ABI 的 payload；prepared 与 packaged framework 同一性使用 Mach-O `LC_UUID` 集合派生的 `identity_sha256`，raw SHA 分别保留审计但不要求相等。

## 禁止模式

- 不要把macOS build artifact路径写死进Rust crate、Podspec或carrier package；workspace cache与release/candidate hook output都由internal helper和canonical target matrix管理。
- 不要恢复 Pod resource bundle、`Libraries` materialization、fixed bundle loader 或 fallback branch。
- 不要新增平台专属 request/response 行为；HTTP 行为属于 shared core。
- 不要在 `proxy_source.rs` 重新实现共享 Apple parser 规则。

## 检查

- `cargo test -p nexa_http_native_macos_ffi`
- `cargo test -p nexa_http_native_apple_proxy`
- `fvm dart test packages/nexa_http_native_macos/test/build_hook_test.dart`
- `fvm dart test test/native_payload_identity_test.dart test/native_artifact_uniqueness_test.dart test/verification/native_asset_hook_identity_test.dart`
- Catalog `verify-integration --execution apple-macos` 完整 suite。
