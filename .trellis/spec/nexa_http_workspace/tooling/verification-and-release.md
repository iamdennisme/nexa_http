# Verification Catalog 与 release transaction 契约

本规范把 [ADR-0009](../../../../docs/adr/0009-gated-immutable-release-transaction.md)、[ADR-0010](../../../../docs/adr/0010-verification-catalog-owns-gate-composition.md) 和共享 [验证命令与 CI 所有权契约](../../guides/verification-command-contract.md) 落到根 workspace tooling。

## Verification ownership

- [`scripts/workspace_tools.dart`](../../../../scripts/workspace_tools.dart) 是唯一公开验证 CLI，并保持薄入口。
- [`scripts/verification/catalog.dart`](../../../../scripts/verification/catalog.dart) 注册原子 check、suite membership、dependency 和 execution coverage；target matrix 由 internal canonical matrix 投影。
- 公开 gate 只有 `verify-static`、`verify-integration`、`verify-release-candidate`。单项 `check` 只用于诊断，不能替代完整 suite。
- Workflow YAML 只拥有 runner、permissions、secrets、动态 matrix、job dependency 和 Actions artifact transport；不复制 check list、target list、native build command 或 filename。
- Root Dart contract tests 独立于 package discovery 运行，因此 Trellis/config/docs 治理也进入 `verify-static --execution static-linux`。

## Candidate and release transaction

- [`scripts/release_transaction.dart`](../../../../scripts/release_transaction.dart) 只接受明确 version、完整 commit SHA 和 typed subcommand；release 不由 public tag push 触发。
- 三个 producer execution 只 build 一次并原地 assemble 一个含九个 Native Asset、manifest 和 `SHA256SUMS` 的 immutable candidate set。
- Android、iOS、macOS、Windows gate 消费同一 candidate ID/digest，分别证明 ABI、唯一 payload、request、callback、body release 和 client close；aggregate 精确覆盖 matrix 后唯一 publisher 才能创建 tag/Release。
- Publisher 不重新 build、rename、copy 或生成 metadata；失败只清理本 transaction 确认拥有的 public state。
- Android row 的 emulator readiness、唯一 release APK、INTERNET permission、`adb reverse`、phase/failure diagnostics 和 proof marker 由 workspace verification owner 维护，不进入 Android FFI crate spec。

## Required tests and checks

- `test/verification/catalog_test.dart`、planner/executor/report/target matrix tests 锁定 Catalog 图、suite membership 和 coverage。
- `test/verification/ci_workflow_test.dart` 锁定动态 matrix、完整 suite、唯一 publisher、permissions 和旧 authority absence。
- `test/release_transaction_test.dart`、CLI 与 publication gateway tests 锁定 input、candidate identity、remote ownership 和 rollback。
- native payload identity、artifact uniqueness、ABI verifier、development/external/released consumer tests 锁定同一 artifact 从 preparation 到 runtime 的证明链。
- 治理或 tooling 变化至少运行相关 focused tests；最终运行 `fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux`。

## Prohibited duplication

- 不在 workflow、README、carrier spec 或 platform FFI spec 重建 check/target/release list。
- 不保留旧 CLI alias、forwarder、tag-triggered publisher、第二 candidate tree 或 skip-as-pass platform branch。
- 不以 archived task 或 CI log 代替当前 Catalog、report schema 和 executable contract。

## Scenario: Trellis routing 与文档完整性

### 1. Scope / Trigger

- Trigger：修改 `.trellis/config.yaml`、package/spec 目录、架构/ADR 导航、tracked Markdown 路径或 Trellis update 后的 project customization。
- 本场景只治理开发上下文路由和文档 contract，不改变产品 runtime、build 或 release 行为。

### 2. Signatures

```text
python3 ./.trellis/scripts/get_context.py --mode packages
python3 ./.trellis/scripts/get_context.py --mode packages --json
fvm dart test test/trellis_governance_test.dart
```

JSON discovery 的稳定字段是 `packages[].name`、`packages[].path`、`packages[].specLayers`、`packages[].default` 和顶层 `defaultPackage`。

### 3. Contracts

- `.trellis/config.yaml` 显式登记 13 个 owner：root workspace、public SDK、internal helper、四个 carrier、Rust core、Apple parser 和四个平台 FFI crate。
- `defaultPackage` 必须为 null。跨 package task 可以保持 `package: null`；package-local task 必须显式选择真实 owner，不能静默落到 Rust core。
- 每个 config path 必须存在，每个 discovery layer 必须有 `index.md`；Rust package layer 统一为 `rust/`，不保留 `backend/` alias、symlink 或 forwarding doc。
- Package index local links和所有 tracked Markdown 的真实本地链接必须存在；fenced 示例、外部 URL、anchor 和显式模板路径不作为文件 contract。
- Package specs 不包含未填模板；状态/持久化与诊断规则归入真实 owner，不建立独立 database/logging 模板文件。
- `docs/architecture.md` 只导航 context、ADR、spec、authority/取代规则和 provenance，不成为新的 decision source。
- Trellis update 后必须保留这份 project-owned package map；若 auto-detection 退回 Cargo-only routing，治理 test 直接阻断 `verify-static`。

### 4. Validation & Error Matrix

- owner 缺失、多余、顺序/path/layer 漂移或 `defaultPackage != null` -> package discovery contract 失败。
- configured path 不存在或 layer 缺 `index.md` -> routing target 失败。
- 项目 Rust spec 引用 `backend/`，或出现 `database-guidelines.md` / `logging-guidelines.md` -> clean migration contract 失败。
- Index/Markdown 指向不存在的真实本地目标 -> navigation contract 失败；历史目标从未保留时改为明确文本，不制造空文件。
- package spec 命中 `test/trellis_governance_test.dart` 的 `templateTerms` matcher -> code-backed spec contract 失败。
- internal package 旧描述、`v1.0.2` 集成示例或 FFI quality 中出现 carrier/CI/release orchestration -> ownership/current-fact contract 失败。

### 5. Good/Base/Bad Cases

- Good：Dart transport task 选择 `nexa_http`/`dart`，release tooling task 选择 `nexa_http_workspace`/`tooling`，各自只加载 owner spec 与 shared guides。
- Base：架构 review task 保持 `package: null`，由任务 artifacts 明确列出跨 owner 范围。
- Bad：省略 package 后自动加载 `nexa_http_native_core`，或为迁移保留 `backend/` 转发目录。

### 6. Tests Required

- `test/trellis_governance_test.dart` 必须通过真实 `get_context.py --mode packages --json`，不能独立重写 YAML parser。
- 测试断言 13 个 literal owner/path/layer、null default、path/index existence、完整 spec topology 和 index-local links。
- 测试扫描 worktree 中 tracked/unignored Markdown，跳过 fenced examples/外部目标，并报告每个断链的 source/target。
- 测试拒绝旧 layer、薄模板文件、陈旧术语/版本、spec 模板占位内容和 FFI quality 的跨 owner 规则。
- 最终由 `verify-static --execution static-linux` 运行 root Dart tests，保证本地与 CI 消费同一 contract。

### 7. Wrong vs Correct

#### Wrong

```yaml
packages:
  nexa_http_native_core:
    path: native/nexa_http_native_core
default_package: nexa_http_native_core
```

#### Correct

```yaml
packages:
  nexa_http_workspace:
    path: .
  nexa_http:
    path: packages/nexa_http
  nexa_http_native_core:
    path: native/nexa_http_native_core
# No default_package: cross-package work remains explicitly unscoped.
```
