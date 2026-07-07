# Align architecture rules, context, docs, and code

## Goal

先确认 `nexa_http` 当前架构应该是什么，再按这个架构修正 AI/vibe coding 使用的 spec 和 context，随后修正框架文档。代码修复留到规则和文档稳定后再做。

当前状态：架构已由用户确认。本任务正在执行 spec/context、README、verification、ADR 和 AI 文档清理。

## Background

前序审计发现 `.trellis/spec/`、`CONTEXT.md`、`docs/adr/` 和 workspace context 已经有一部分规则，但当前规划把问题过早收敛为“补 spec 覆盖”。用户指出这会倒置顺序：如果架构本身没有先确认，后续 spec/context、文档和代码都可能围绕错误规则收敛。

正确顺序是：

1. 确认当前架构和权威规则。
2. 基于架构修正 vibe coding spec 和 context。
3. 基于规则修正框架文档。
4. 最后修复代码。

## Confirmed Facts

- `CONTEXT.md` 已存在，记录当前领域词汇：`public Dart SDK`、`platform carrier`、`nexa_http_native_internal`、`native transport`、`Rust transport core`、`platform FFI crate`、`uniform C ABI`、`proxy settings`、`platform runtime state`、`native artifact`、`release artifact`、`clean-host consumer` 等。
- `docs/adr/` 已存在四个 accepted ADR：
  - `0001-public-dart-sdk-root-api.md`
  - `0002-explicit-platform-carrier-dependencies.md`
  - `0003-unified-async-ffi-transport.md`
  - `0004-platform-owned-proxy-runtime-state.md`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md` 已定义 Flutter SDK 集成核心规则：宿主 runtime 只 import `package:nexa_http/nexa_http.dart`，依赖声明显式列出主包和目标平台 carrier package，native 生命周期由 SDK/carrier/build hook 自持。
- 当前 Trellis package 配置只声明 5 个 Rust crate。仓库实际还包含 Dart SDK、internal native layer、platform carrier packages、workspace/release scripts 等未纳入 package spec 的架构边界。
- 现有平台 FFI spec 颗粒度不均：Android 已经比 macOS/iOS/Windows 更具体。
- workspace context 中仍有过期或冲突信息，例如 `.trellis/workspace/index.md` active developer 为 none、语言规则和 `.trellis/spec` 中文规则不一致。
- 用户确认外部 App 集成规则：不是只依赖一个包；`pubspec.yaml` 必须同时声明 `nexa_http` 主 SDK 和目标平台 carrier package，runtime 代码只 import `package:nexa_http/nexa_http.dart`。
- 用户修正最终产物口径：对外发布/交付产物不应把 `native runtime artifacts` 作为独立类别。外部集成主要依赖 SDK packages 和发布版 native 下载产物；运行时动态库是 build hook 从 workspace source 或 release asset 物化到 carrier/App 内部的结果。

## Requirements

### Architecture First

- 以 monorepo 子项目视角确认架构，而不是把每个 runtime/build 组件都当成一层。
- 当前已确认的顶层架构是两大子系统：
  - Flutter SDK 层：对宿主 Flutter App 暴露 Dart API，并负责和 native 层建立标准 Flutter 集成。
  - 原生 native 层：包含各平台 native 实现、共享 Rust core、平台动态库和系统能力读取。
- 在两层架构下，再解释内部解耦机制：
  - Flutter SDK 层如何通过 public API、internal native helper、platform carrier package 和 build hook 解耦。
  - native 层如何通过 shared Rust core、platform FFI crate 和统一 C ABI 解耦。
  - 两层之间如何通过 FFI ABI、artifact packaging 和 platform registration 结合。
- 以现有 `CONTEXT.md`、4 个 accepted ADR、项目分层契约和 Flutter SDK 编写契约作为当前规则来源，并按“两层架构”解释和复核。
- 明确哪些历史说法或旧设计不再作为权威来源。

### Then Fix Vibe Coding Spec And Context

- 修正 `.trellis/spec/`、`.trellis/workflow.md`、`.trellis/workspace/`、`AGENTS.md` 或相关 AI context 中和确认架构冲突、过期、缺失的内容。
- 新增或增强 spec 前，先定义规则归属：包级 spec、shared guide、ADR/CONTEXT、workflow/context 哪一层负责。
- 生成的 spec 必须可被后续 AI 在正确时机发现和加载。
- `.trellis/spec/` 文档必须遵守中文规则；代码标识符、包名、官方术语可保留英文。

### Then Fix Framework Docs

- 修正规则确定后暴露给人类开发者的框架/项目文档，例如 README、verification playbook、ADR 和 CONTEXT 中的冲突和遗漏。
- 文档修复必须服从已确认架构，不用文档反向定义架构。
- `openspec/` 当前已经不存在，不再把 OpenSpec 主 specs 当作当前权威文档；历史 Trellis task 归档只作为追溯记录保留。

### Then Fix Code

- 只有当架构规则和文档都确认后，才进入代码修复。
- 代码修复必须引用前面确定的规则，并通过相应测试或验证命令证明符合架构边界。

## Acceptance Criteria

- [x] PRD 明确当前任务顺序：架构确认 -> spec/context -> 框架文档 -> 代码。
- [x] 用户确认架构权威来源和优先级。
- [x] `design.md` 描述确认后的架构边界、规则归属、文档归属和代码修复入口。
- [x] `implement.md` 按阶段列出可独立验证的执行计划。
- [x] 生成或修改的 spec/context 不和 `CONTEXT.md`、accepted ADR、Flutter SDK 编写契约冲突。
- [x] 文档清理后没有明显模板占位、死链接、OpenSpec 当前入口残留或和两层架构冲突的 AI 文档。
- [x] 搜索和格式检查通过。

## Out of Scope

- 修改 SDK/runtime 代码。
- 修改 release artifact 实际生成逻辑。
- 重写 OpenSpec 历史归档。
- 重新打开 accepted ADR，除非用户明确要求架构变更。

## Open Questions

- 无。当前按已确认两层架构清理文档。
