# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，平台 `lib.rs` 不复制 wrapper。
- `WindowsProxySource` 只拥有 Internet Settings registry adapter 与 proxy parser，refresh mode 保持 `ConstructionBoundary`。
- `ProxyEnable`、`ProxyServer`、`ProxyOverride`、bypass 和 default state 必须由 `tests/proxy_settings.rs` 覆盖。

## 禁止模式

- 不要新增平台专属 HTTP 行为。
- 不要新增 stdout/stderr 日志、registry 写入、持久化 proxy cache 或 shared runtime 副本。

## 检查

- `cargo fmt --all --check`
- `cargo clippy --no-deps -p nexa_http_native_windows_ffi --all-targets -- -D warnings`
- `cargo test -p nexa_http_native_windows_ffi`
