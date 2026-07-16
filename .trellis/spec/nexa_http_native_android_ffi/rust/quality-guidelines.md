# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`，保证动态库产物和 Rust tests 都可用。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，禁止在平台 `lib.rs` 复制 wrapper。
- Proxy 解析 helper 必须可测试；`current_proxy_settings_for_test()` 接收 `BTreeMap<String, String>`，避免测试依赖真实 Android 设备。
- Android proxy source 使用 `RefreshMode::Polling`，当前轮询间隔由 `ANDROID_PROXY_REFRESH_INTERVAL = 15s` 集中定义。
- `getprop` 只在 `#[cfg(target_os = "android")]` 代码中执行，非 Android 单元测试不得尝试运行系统命令。
- Android 字段映射、默认端口、bypass 分隔和 refresh policy 必须由 `tests/proxy_settings.rs` 直接覆盖。

## 禁止模式

- 不要新增平台专属 request/response 行为；HTTP 行为属于 shared core。
- 不要在测试中 shell 出真实 `getprop`；测试应通过 `current_proxy_settings_for_test()` 注入字段。
- 不要把 Android proxy refresh 改成无界忙轮询；间隔必须有明确常量和测试约束。
- 不要新增 stdout/stderr 日志、持久化 proxy cache 或 shared runtime 副本。

## 检查

- `cargo fmt --all --check`
- `cargo clippy --no-deps -p nexa_http_native_android_ffi --all-targets -- -D warnings`
- `cargo test -p nexa_http_native_android_ffi`
