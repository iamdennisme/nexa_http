# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，平台 `lib.rs` 不复制 wrapper。
- 纯 proxy parser 必须使用 `nexa_http_native_apple_proxy` 并由其 tests 覆盖。
- `IosProxySource` 只拥有 SystemConfiguration raw-value adapter，refresh mode 保持 `ConstructionBoundary`。
- raw-value mapping、default state 和 parser wiring 必须由 `tests/proxy_settings.rs` 覆盖。

## 禁止模式

- 不要新增平台专属 HTTP 行为。
- 不要在 `proxy_source.rs` 重新实现共享 Apple parser 规则。
- 不要新增 stdout/stderr 日志、持久化 proxy cache 或 shared runtime 副本。

## 检查

- `cargo fmt --all --check`
- `cargo clippy --no-deps -p nexa_http_native_ios_ffi --all-targets -- -D warnings`
- `cargo test -p nexa_http_native_ios_ffi`
- `cargo test -p nexa_http_native_apple_proxy`
