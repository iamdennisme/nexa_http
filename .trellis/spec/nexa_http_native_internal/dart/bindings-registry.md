# Native bindings registry 契约

Bindings registry 把 carrier-owned CodeAsset registration 连接到 public SDK 的统一 Native Transport，同时保持 carrier 与 FFI 细节对宿主隐藏。

## Contract

- [`nexa_http_native_bindings.dart`](../../../../packages/nexa_http_native_internal/lib/src/native/nexa_http_native_bindings.dart) 定义 bindings interface、factory、registration 和 isolate-local lazy instance。
- 每个平台 carrier 生成与自身 CodeAsset ID 对齐的 `lib/src/native/nexa_http_native_ffi.dart`，并在 plugin registration 时提交 immutable `NexaHttpNativeBindingsFactory`。
- 同一个 asset ID 的重复 registration 幂等；不同 asset ID 在同一 isolate 冲突时立即失败，不能静默替换已选平台。
- 首次 transport 使用时 lazy 创建 bindings，之后返回同一 instance；测试 reset 只存在于 internal testing surface，不成为宿主 API。
- 共享 ABI structs/types 位于 `lib/src/native/`；主包只依赖稳定 internal interface，不打开 `DynamicLibrary`，不理解 artifact 路径。

## Failure boundary

- 未注册 carrier、factory 创建失败、symbol unavailable 或 bindings conflict 必须携带 asset ID/stage 并由 public mapper 收敛为 `NexaHttpFailureKind.unavailable`。
- ABI corruption、malformed result 或 impossible registry state 收敛为 `internal`；不暴露 raw `ArgumentError`/`StateError` 给正常 HTTP execution。
- Registry 不扫描 platform、filesystem、environment 或 package graph；显式 plugin registration 是唯一 authority。

## Required tests

- [`nexa_http_native_bindings_registry_test.dart`](../../../../packages/nexa_http_native_internal/test/nexa_http_native_bindings_registry_test.dart) 覆盖首次注册、same-ID 幂等、different-ID conflict、lazy once 和 reset isolation。
- 四个平台 `test/*_plugin_test.dart` 覆盖 plugin registration 使用 carrier-owned asset ID 与 factory。
- [`nexa_http_native_data_source_factory_test.dart`](../../../../packages/nexa_http/test/nexa_http_native_data_source_factory_test.dart) 覆盖主包只通过 registry interface 获得 bindings。
- ABI header/generated bindings freshness 和 native symbol contract tests 必须与 registry factory 使用的接口一致。

新增 carrier 或修改 asset ID 时必须同时更新 canonical target matrix、carrier plugin test 和 registry conflict tests。
