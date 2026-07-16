# Trellis architecture spec governance

## Goal

让 Trellis 的 package/spec 路由、架构文档索引和验证契约覆盖真实的 Flutter SDK、carrier、artifact/release tooling 与 native layer，使后续任务加载正确的规则，并删除不再适用或归属错误的规范文件。

## Background

- 当前基线是已发布并通过四平台验证的 `v2.0.1`；本任务只治理 Trellis 路由、spec 和文档，不改变产品行为。
- 根 `pubspec.yaml` 定义真实的 `nexa_http_workspace`，仓库另有 `nexa_http`、`nexa_http_native_internal` 和四个平台 carrier package；`Cargo.toml` 定义 native core、Apple proxy parser 和四个平台 FFI crate。
- `.trellis/config.yaml` 目前只登记六个 Rust crate，并把 `nexa_http_native_core` 设为默认 package。没有显式 package 的 Dart/tooling 任务因此会错误加载 Rust core 规范。
- `.trellis/spec/` 目前只覆盖 Rust crate。平台 FFI `quality-guidelines.md` 混入 carrier hook、Flutter packaging、CI runner 和 release proof 规则，例如 Android spec 同时描述 `getprop`、APK、Actions emulator 和 runtime fixture。
- 五个 native package 各有一份 `database-guidelines.md` 和 `logging-guidelines.md`。这些文件只有各自 `index.md` 引用，内容主要是重复的“无持久化”和“禁止 stdout/stderr 日志”规则。
- `CONTEXT-MAP.md`、`docs/adr/`、`.trellis/spec/`、README 和 `docs/verification-playbook.md` 承担不同职责，但当前没有统一的可发现索引说明 authority、supersession 和 review provenance。
- `packages/nexa_http_native_internal/pubspec.yaml` 仍使用过期描述 `Internal merged native layer`；`project-layering-contract.md` 的集成示例仍使用 `v1.0.2`。
- `.trellis/workspace/index.md` 的会话统计已经落后于个人索引；一个归档任务设计文档有 11 条失效链接，其中 9 条由归档后目录层级变化导致，2 条指向未保留的任务。
- 三个 Trellis update backup 已在本次会话中确认无用并清理；`.dist/` 和 `.claude/tmp/` 是忽略的构建/测试产物，不属于本任务的文档源。
- 用户已确认六个 Rust package 的 spec layer 从模板化的 `backend/` 原子迁移为语义准确的 `rust/`，不保留兼容目录或转发链接。

## Requirements

### R1. Route real ownership boundaries

- 在 `.trellis/config.yaml` 登记根 workspace、public Dart SDK、internal artifact helper、四个平台 carrier package、native core、Apple proxy parser 和四个平台 FFI crate。
- 不再把 `nexa_http_native_core` 作为跨域默认 package。未指定 package 的任务保持跨 package，而 package-local 任务必须显式选择真实 owner。
- `get_context.py --mode packages` 必须能展示每个 package 的真实路径和可用 spec layer。

### R2. Reshape specs from code ownership

- 为 public Dart SDK/native transport、internal artifact lifecycle/bindings、carrier contract 和 workspace verification/release tooling建立 code-backed specs。
- 六个 Rust package 的 spec layer 统一使用 `rust/`；同步当前文档、ADR、task link 和 JSONL path metadata，不保留 `backend/` alias。
- 共享 carrier、artifact identity、release transaction 和 verification 规则只保留一个权威位置；平台 package spec 只记录真实平台差异。
- 平台 FFI spec 只保留 Rust ABI、platform capability source、proxy adapter 和 crate-local tests，不再拥有 Flutter carrier、CI 或 release orchestration 规则。
- 将 10 份薄弱的 database/logging spec 中仍有价值的规则合并到共享或 package-local owner 后删除原文件，并同步所有 `index.md`。
- 所有 spec 使用真实源码、测试和文档路径；不得保留 placeholder、通用模板段落或复制的跨平台规则。

### R3. Establish a living architecture index

- 建立人类可发现的 living architecture/ADR index，列出四个 bounded contexts、10 个 ADR 的状态、当前项目分层契约、实现 spec 和 verification playbook。
- 明确 authority 顺序与 supersession：glossary 只定义语言；accepted ADR 拥有长期架构决策；项目/包 spec 将决策转成当前执行约束；README/playbook 描述消费和操作方式，不反向覆盖 ADR/spec。
- 记录当前 review provenance：相关归档任务、关键架构提交、`v2.0.1` known-good release 及验证证据入口。
- 从 `README`、`CONTEXT-MAP.md` 和 `.trellis/spec/guides/index.md` 可以发现该索引。

### R4. Synchronize metadata and current facts

- 更新 carrier README，使其准确描述 hook adapter、plugin registration 和 carrier-owned bindings factory，不把 carrier 写成第二 runtime API。
- 修正 `nexa_http_native_internal` package description，删除 `Internal merged native layer` 等漂移术语。
- 更新 ADR current-source 列表、项目分层示例版本和 known-good evidence，使其与 `v2.0.1` 和当前代码一致。
- 简化 `.trellis/workspace/index.md` 中不会被脚本维护的易漂移统计，保留稳定的 workspace/journal 使用说明。

### R5. Preserve history without broken navigation

- 保留 `.trellis/tasks/archive/` 作为历史记录，不批量删除归档 PRD/design/implement。
- 修复 `07-10-v2-public-http-api-cutover/design.md` 中可恢复的相对链接；对从未保留的父任务/下游任务改为明确的历史文本，不制造虚假文件。
- 文档整理不触碰忽略的 `.dist/` 或 `.claude/tmp/` 产物。

### R6. Make routing and documentation verifiable

- 增加自动化 contract test，执行 Trellis package discovery 并断言 Dart/tooling 任务不再默认路由到 `nexa_http_native_core`。
- 验证 config 中每个 package path 存在、每个声明的 spec layer 有 `index.md`，索引引用与最终文件集一致。
- 验证被跟踪 Markdown 的本地链接、spec placeholder 搜索和旧术语/旧版本 absence。

## Acceptance Criteria

- [ ] Trellis package discovery 能选择 root workspace、public SDK、internal helper、四个平台 carrier 和六个 Rust package，且没有错误的 Rust core 默认路由。
- [ ] 新 specs 全部基于当前代码，索引可发现，无 placeholder、无跨平台规则复制。
- [ ] FFI specs 不再包含 carrier/CI/release orchestration；database/logging 模板文件已在规则迁移后删除。
- [ ] Living architecture index 明确 authority、ADR 状态、supersession 和 review provenance，并从三个入口可发现。
- [ ] Carrier README、internal package description、ADR sources、版本示例和 workspace index 与当前事实一致。
- [ ] 归档任务保留，11 条已知断链已修复或改成诚实的历史说明。
- [ ] Routing contract test、Markdown link check、placeholder/旧术语搜索和相关 Dart tests 全部通过。

## Out of Scope

- 改变两层项目架构、四个 bounded contexts、public API、native runtime、artifact behavior 或 release workflow。
- 重写历史 task 的需求、设计结论或实现记录。
- 清理 `.dist/`、`.claude/tmp/` 或其他构建产物。
- 执行 post-v2 的 proxy、Rust executor 或 Dart native transport 重构 backlog。
