# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，并由 Apple runner 检查最终 Mach-O symbols。
- 纯 proxy parser 必须使用 `nexa_http_native_apple_proxy` 并由其 tests 覆盖。
- iOS device/simulator target 变化必须同步 target matrix、build hook、podspec 和 release workflow。

## 禁止模式

- 不要把 iOS framework 路径写死进 Rust crate。
- 不要新增平台专属 HTTP 行为。
- 不要让 platform crate 读取或修改宿主 native 工程。
- 不要在 `proxy_source.rs` 重新实现共享 Apple parser 规则。

## 检查

- `cargo test -p nexa_http_native_ios_ffi`
- `cargo test -p nexa_http_native_apple_proxy`
- `fvm dart test packages/nexa_http_native_ios/test/build_hook_test.dart`
