# Deepen Dart native transport module

## Goal

在保持 v2 public API、统一 C ABI、failure taxonomy、cancellation linearization、lease lifecycle 和 body ownership/copy budget不变的前提下，把 `packages/nexa_http` 当前互相穿透的 `data/`、`native_bridge/`、`internal/transport/` 收敛为单一、单向依赖的 `internal/native_transport/` 垂直模块。

## Background

- 前序提交 `080f4e1` 已把 lease reuse、close/dispose、request/response mapping 和 cancellation handoff收敛到 `NexaHttpNativeTransport` facade；本任务只整理当前稳定实现的物理模块边界，不重做生命周期设计。
- 当前19个 transport-only Dart文件分散在 `data/dto`、`data/mappers`、`data/sources`、`native_bridge`、`internal/transport` 和 `internal/testing`。
- `internal/transport/nexa_http_native_transport.dart` 正向依赖 mapper/source/factory，而 `data/sources` 又反向依赖 `internal/transport/transport_response.dart`，形成目录级反向依赖；`native_bridge` 再依赖 source。
- `NexaHttpClient` 同时 import transport facade、testing override和data source factory，并在上层装配默认 adapter，导致client知道低层 native adapter选择。
- 11个 package tests直接 import旧路径；当前 `.trellis/spec/nexa_http/dart/{index,native-transport}.md` 与 ADR-0003/0006/0007/0008 记录了旧source path。

## Dependencies

- 以 `v2.0.1` 和已通过验证的当前 main行为为基线。
- 依赖已完成的 Rust executor拆分 `39d4219`；本任务不修改 Rust core、C header、generated FFI bindings或platform FFI crates。
- 遵守 ADR-0001、ADR-0003、ADR-0006、ADR-0007、ADR-0008 与 `.trellis/spec/guides/flutter-sdk-authoring-contract.md`。

## Requirements

### R1. Preserve external contracts

- `package:nexa_http/nexa_http.dart` exports、public type/member signatures和宿主runtime import保持不变。
- 统一 async FFI execution、native symbols、error payload、typed failure mapping和carrier registration保持不变。
- 不修改 pubspec、artifact、hook、target matrix、release metadata或外部consumer setup。

### R2. Establish one vertical feature boundary

- 将现有 DTO/generated files、mappers、data source interface/FFI helpers、factory、transport facade/response mapper/payload和transport-only testing override全部移动到扁平目录 `lib/src/internal/native_transport/`。
- 删除旧 `lib/src/data/`、`lib/src/native_bridge/`、`lib/src/internal/transport/` 和 `lib/src/internal/testing/`；不保留barrel、forwarder、alias或双轨import。
- 不在新feature目录内重建 `dto/mappers/sources/native_bridge` 子层；文件名前缀已经提供职责区分，扁平目录用于消除目录级环。

### R3. Enforce dependency direction

- `NexaHttpClient` 生产代码只 import `nexa_http_native_transport.dart` facade；默认 factory/testing override选择由native transport模块内部完成。
- native transport可以依赖public API模型、`internal/body`、`internal/config`、`internal/errors` 和 `nexa_http_native_internal`，不得反向依赖 `client/` 或 `nexa_http_client.dart`。
- `internal/body/response_body_owner.dart`、`internal/config/client_options.dart`、`internal/errors/nexa_http_failures.dart` 保持中性共享边界，不移入feature module。

### R4. Preserve lifecycle and ownership owners

- `NexaHttpNativeTransport` 继续拥有lazy data source/client lease、reuse、close/dispose、request mapping和response handoff。
- `RealCall` 继续拥有public Call状态和at-most-once cancellation forwarding；FFI data source/pending registry继续拥有request ID、native cancel acknowledgment、Callback Commit等待和late callback cleanup。两者是不同状态机，不合并。
- Request body构造/mapping/DTO保持同一Dart buffer identity；非空dispatch仍只有一次Dart-to-native copy。
- Response decoder/mapper/public body继续传递同一个owner；binary result与body保持exactly-once release。

### R5. Clean source, tests, and documentation cutover

- 更新所有production/test imports、Freezed/json_serializable part placement、spec和current ADR source references到新路径。
- 已归档任务文档保留历史路径，不进行回写。
- 新增 `native_transport_dependency_test.dart`，拒绝旧目录回归、模块外production code绕过facade，以及feature module反向依赖client/root。

### R6. Flutter SDK contract mapping

- Host依赖声明不变：`nexa_http` 加目标平台carrier；host runtime仍只 import `package:nexa_http/nexa_http.dart`。
- `nexa_http_native_internal` bindings、carrier registration、artifact download/cache/packaging owner均不变且继续隐藏。
- 不新增mirror/offline/debug等配置面；既有结构化failure stage/platform diagnostics不变。
- Package tests/analyze证明共享Dart路径；本机Apple `verify-integration`证明clean-host iOS/macOS runtime。Android/Windows release gate仍由对应动态runner负责，本任务不把不可用平台记为skip success。

### R7. Verification discipline

- 先运行package baseline；RED先证明dependency contract在旧拓扑失败，再执行机械移动与最小装配调整。
- 运行focused lifecycle/cancellation/ownership/public surface tests、build_runner freshness、package analyze和full package suite。
- 搜索production/spec/current ADR无旧路径，`git diff --check`通过。

## Acceptance Criteria

- [x] AC1 (`R2`, `R3`): `lib/src/internal/native_transport/` 是唯一transport feature目录，四个旧目录不存在且无forwarder/barrel。
- [x] AC2 (`R1`): root public exports、C ABI、bindings、pubspec、carrier/artifact files无变化。
- [x] AC3 (`R3`): `NexaHttpClient`只依赖transport facade；dependency contract拒绝外部绕过与反向依赖。
- [x] AC4 (`R4`): lease reuse/close、Call cancellation、dispatch race、request copy和response release全部回归通过。
- [x] AC5 (`R5`): 11个直接import旧路径的tests及current specs/ADRs完成clean cutover；归档历史未改写。
- [x] AC6 (`R7`): build_runner、Dart format/analyze、full package tests、public surface tests与legacy search通过。
- [x] AC7 (`R6`, `R7`): Apple `verify-integration`通过或明确记录真实外部prerequisite blocker；没有新增host集成步骤。
- [x] AC8: TDD RED/GREEN与最终验证证据写入任务工件和最终报告。

## Out Of Scope

- Public API、failure taxonomy、cancellation策略或body semantics再设计。
- Rust executor/core、C ABI、ffigen output或platform FFI adapter修改。
- Carrier hook、Native Asset、artifact/release transaction、target matrix或CI改造。
- 把 `RealCall`、shared body/config/error seam并入native transport。
