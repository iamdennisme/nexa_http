# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`，保证动态库产物和 Rust tests 都可用。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，禁止在平台 `lib.rs` 复制 wrapper。
- Android native artifact 只由 canonical target matrix 驱动 typed build script，输出到 Flutter hook 的 target-scoped directory，并由 carrier hook 将 preparation 返回的同一个 `File` 交给 `CodeAsset`。
- 最终 APK 的目标 ABI 目录必须只包含一个导出 canonical `nexa_http_*` ABI 的 payload，并通过 Catalog `native-abi` exact comparison 与 artifact uniqueness check。
- Proxy 解析 helper 必须可测试；`current_proxy_settings_for_test()` 接收 `BTreeMap<String, String>`，避免测试依赖真实 Android 设备。
- Android proxy source 使用 `RefreshMode::Polling`，当前轮询间隔由 `ANDROID_PROXY_REFRESH_INTERVAL = 15s` 集中定义。
- `getprop` 只在 `#[cfg(target_os = "android")]` 代码中执行，非 Android 单元测试不得尝试运行系统命令。

## 禁止模式

- 不要把 Android build artifact 路径写死进 Rust crate、Gradle 或 carrier package；路径由 canonical target matrix 和 Flutter hook output contract 管理。
- 不要恢复 Gradle Rust build、`jniLibs` copy、manual `DynamicLibrary.open` 或 fallback branch。
- 不要新增平台专属 request/response 行为；HTTP 行为属于 shared core。
- 不要在测试中 shell 出真实 `getprop`；测试应通过 `current_proxy_settings_for_test()` 注入字段。
- 不要把 Android proxy refresh 改成无界忙轮询；间隔必须有明确常量和测试约束。

## 检查

- `cargo test -p nexa_http_native_android_ffi`
- `fvm dart test packages/nexa_http_native_android/test/build_hook_test.dart`
- `fvm dart test test/native_artifact_uniqueness_test.dart test/verification/native_asset_hook_identity_test.dart`
- Catalog `verify-integration --execution android-linux` 完整 suite。
