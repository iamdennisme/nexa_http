# Trellis architecture spec governance

## Goal

让 Trellis 的 package/spec 路由、living architecture index、review provenance 和文档元数据覆盖真实的 Flutter SDK、carrier、artifact/release tooling 与 Native layer，而不是默认把 Dart/tooling 任务路由到 Rust core。

## Dependencies

- 以已发布并通过四平台验证的 `v2.0.1` 架构、ADR、spec 和 release evidence 为治理基线。
- 当前已知限制：Trellis 只登记 Rust packages，因此本轮新建 Dart/tooling child 暂时显示为默认 `nexa_http_native_core`；本任务必须修复该事实而不是掩盖它。

## Requirements

- 在 `.trellis/config.yaml` 登记 public Dart SDK、internal artifact helper、shared carrier contract 和 workspace/release tooling 的可路由边界。
- 为 Dart SDK/native transport、artifact/loading、carrier contract、verification/release tooling 建立 code-backed package/layer specs，避免复制平台共同规则。
- 建立 living architecture/ADR index，明确 glossary、ADR、Trellis spec、README 和 verification playbook 的 authority priority 与 supersession 规则。
- 持久化 architecture review 的资料清单、发现、候选、决策和后续任务，不再只引用 OS temp HTML。
- 同步 carrier README、internal package description、ADR current sources 和版本/known-good evidence，删除陈旧术语。
- 更新 task/skill routing tests，证明 Dart/tooling 任务不再默认落到 Rust core。

## Acceptance Criteria

- [ ] Trellis package discovery/creation能选择 public Dart SDK、internal helper、carrier 和 verification/release scopes。
- [ ] 新 specs 全部基于当前代码，索引可发现，无 placeholder 或跨平台规则复制。
- [ ] Living architecture index 明确 authority priority、ADR 状态和 review provenance。
- [ ] 旧 “Internal merged native layer”等漂移术语和陈旧 sources/evidence 已修正。
- [ ] Routing/validation tests 证明相关 task 不再错误归属 `nexa_http_native_core`。

## Out of Scope

- 改变两层项目架构或四个 bounded contexts。
- 行为性 public API/native runtime/release workflow 修改。
