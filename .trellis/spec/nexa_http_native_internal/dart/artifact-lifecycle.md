# Native Artifact lifecycle 契约

本规范把 [ADR-0005](../../../../docs/adr/0005-native-assets-authoritative-artifact-path.md) 和共享 Flutter SDK authoring contract 落到 `nexa_http_native_internal`。一个 target tuple 只能产生一个权威 Native Asset。

## Ownership

- [`nexa_http_native_target_matrix.dart`](../../../../packages/nexa_http_native_internal/lib/src/native/nexa_http_native_target_matrix.dart) 是 target OS、architecture、SDK variant、Rust triple、source/release filename、build script、carrier、execution 和 Native Asset name 的单一事实来源。
- [`nexa_http_native_carrier_artifact.dart`](../../../../packages/nexa_http_native_internal/lib/src/native/nexa_http_native_carrier_artifact.dart) 拥有 target resolution、workspace/release/candidate source 选择与 target-scoped preparation。
- [`nexa_http_native_release_consumer.dart`](../../../../packages/nexa_http_native_internal/lib/src/native/nexa_http_native_release_consumer.dart) 拥有 exact-tag repository identity、manifest、streaming checksum、single temp 和 atomic replace。
- Platform carrier 只适配 `BuildInput` 并把 preparation 返回的同一个 `File` 包装成 `CodeAsset`；本 package 不 import `hooks` / `code_assets`，不接收 `BuildInput`，不返回 `CodeAsset`。

## Source and identity rules

- Workspace source build 与 Verification Catalog producer 共享 `.dart_tool/nexa_http_native/workspace/debug` 的 target file、fingerprint 和 lock；同 tuple 并发只 build 一次。
- Release source 必须来自 dependency checkout 的 exact Git tag 和 canonical GitHub origin；不从 package version、branch 或 workspace HEAD 猜测。
- Candidate directory/ref 必须成对来自 `hooks.user_defines.<carrier>`；缺失、类型错误或 identity 不匹配立即失败，不 fallback 到 workspace/release。
- Materialization path 固定为 `<profile>/<os>/<architecture>/<sdk-or-none>/<release-file-name>`，只写 hook output 或共享 workspace cache，不写回 carrier package。
- Checksum mismatch、下载/写入失败必须保留旧完整 destination，清理本轮唯一 temp，并抛出带 stage、target、SDK ref 和 expected action 的 `NexaHttpNativeArtifactException`。

## Prohibited paths

- 不恢复 Pod resource bundle、`jniLibs`、CMake bundled library、固定 loader、环境变量 shadow source 或第二份 artifact cache。
- 不在 target matrix 之外硬编码 filename、Rust triple、runner 或 release asset list。
- 不把 internal helper 文档化为宿主 runtime API，也不要求宿主运行 native build script。

## Required tests

- [`nexa_http_native_carrier_artifact_test.dart`](../../../../packages/nexa_http_native_internal/test/nexa_http_native_carrier_artifact_test.dart) 覆盖 target、workspace fast path、candidate input 和 materialization ownership。
- [`nexa_http_native_release_consumer_test.dart`](../../../../packages/nexa_http_native_internal/test/nexa_http_native_release_consumer_test.dart) 覆盖 exact tag、pub-cache origin、manifest、checksum 和 atomic replacement。
- [`nexa_http_native_shell_test.dart`](../../../../packages/nexa_http_native_internal/test/nexa_http_native_shell_test.dart) 覆盖平台 shell/toolchain resolution。
- 根 target matrix、artifact uniqueness、payload identity、workspace/release consistency 和 clean-host tests 证明 preparation、packaging、ABI 与 runtime 消费同一 identity。

变更 target 或 artifact lifecycle 后至少运行 internal package tests、四个 carrier hook tests 和 `verify-static --execution static-linux`。
