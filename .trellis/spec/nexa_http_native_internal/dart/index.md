# nexa_http_native_internal Dart 规范

> `packages/nexa_http_native_internal` 是 Flutter SDK 层的内部 artifact 与 bindings helper，不是宿主 runtime API。

## Scope

- canonical native target matrix 与 workspace package discovery
- workspace、release 和 candidate artifact preparation/materialization
- release manifest、checksum、shell/toolchain resolution
- immutable bindings factory registry 与共享 ABI types

## 规范索引

| 规范 | 说明 |
| --- | --- |
| [Artifact lifecycle](./artifact-lifecycle.md) | target matrix、workspace/release/candidate preparation 与 materialization |
| [Bindings registry](./bindings-registry.md) | shared ABI types、carrier registration 和 isolate-local lazy bindings |

## Pre-Development Checklist

- [ ] 修改 artifact lifecycle 前阅读 [Artifact lifecycle](./artifact-lifecycle.md)、[Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md) 和 [项目分层契约](../../guides/project-layering-contract.md)。
- [ ] 修改 registration、asset ID 或 ABI types 前阅读 [Bindings registry](./bindings-registry.md)。
- [ ] 修改 target、execution 或 release identity 前阅读 [验证命令与 CI 所有权契约](../../guides/verification-command-contract.md)、ADR-0009 和 ADR-0010。
- [ ] 保持本 package 不依赖 `hooks`、`code_assets`，不接收 `BuildInput`，不产生 `CodeAsset`。
- [ ] 保持 package 对宿主隐藏，正式 runtime API 仍只来自 `nexa_http`。

## Quality Check

- [ ] `fvm dart analyze packages/nexa_http_native_internal` 通过。
- [ ] `fvm dart test packages/nexa_http_native_internal/test` 通过。
- [ ] target matrix、artifact identity、checksum 和 registry lifecycle tests 覆盖本次变化。
- [ ] 没有第二 artifact source、路径 fallback、可变 bindings replacement 或宿主工程 workaround。
