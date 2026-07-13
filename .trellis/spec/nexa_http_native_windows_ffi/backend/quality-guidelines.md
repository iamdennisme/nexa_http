# 质量规范

## 必需模式

- `Cargo.toml` 同时声明 `cdylib` 和 `rlib`。
- 所有 public C ABI export 通过 core `export_nexa_http_ffi!` 生成，并由 Windows runner 检查最终 PE exports。
- Windows x64 target 变化必须同步 canonical target matrix、build hook、typed build script、release metadata 和 verification matrix。
- 最终runner distribution必须只包含一个导出canonical `nexa_http_*` ABI的payload。Flutter Windows Native Assets安装是byte-for-byte copy，因此prepared/package raw SHA与`identity_sha256`必须完全一致；PE逐section digest只用于mismatch诊断，不得作为放宽身份的替代算法。
- `dumpbin /exports`解析只接受行尾symbol token，必须忽略`Dump of file <path>` banner中的`nexa_http_*`路径片段。
- workspace hook 与 Catalog 调用 shell build script 时必须复用 `resolveNexaHttpNativeBashExecutable()` 定位 Git for Windows；禁止裸 `Process.run('bash')` 命中 WSL stub。
- verification consumer 调用 Flutter 时必须由共享 process runner 把 `flutter` 解析为 `FLUTTER_ROOT/bin/flutter.bat`；禁止在各 consumer adapter复制 Windows shell wrapper。

## 禁止模式

- 不要把 DLL 复制路径写死进 Rust crate。
- 不要恢复 CMake `bundled_libraries` copy、carrier `Libraries` materialization、DLL basename manual loader 或 fallback branch。
- 不要新增平台专属 HTTP 行为。
- 不要在 Rust crate 中尝试修改宿主 Windows project。

## 检查

- `cargo test -p nexa_http_native_windows_ffi`
- `fvm dart test packages/nexa_http_native_windows/test/build_hook_test.dart`
- `fvm dart test test/native_artifact_uniqueness_test.dart test/verification/native_asset_hook_identity_test.dart`
- `fvm dart test packages/nexa_http_native_internal/test/nexa_http_native_shell_test.dart test/verification/integration_checks_test.dart`
- `fvm dart test test/verification/process_runner_test.dart test/verification/external_consumer_adapter_test.dart`
- Catalog `verify-integration --execution windows-x64` 完整 suite。
