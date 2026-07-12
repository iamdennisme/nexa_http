# 验证命令与 CI 所有权契约

> 目的：让本地开发、Pull Request CI 和 release gate 消费同一份可执行验证目录，避免 workflow YAML、脚本和规范分别维护检查列表与 target matrix。

## 唯一权威

`scripts/workspace_tools.dart` 是唯一公开验证 CLI，但必须保持为薄入口。原子检查、suite 组合、matrix 生成、报告和 process orchestration 拆分到 `scripts/verification/` 下的聚焦模块。

所有原子检查必须注册到一个 `Verification Catalog`。Catalog 是以下内容的唯一事实来源：

- check ID、用途和执行函数
- check 属于哪些完整 suite
- check 需要的 host、target、toolchain 和 candidate inputs
- 支持的 target/runner matrix，由 canonical native target matrix 派生

不得在 GitHub Actions YAML、release shell script 或测试中再手写一份检查成员列表或支持 target 列表。

## 完整验证套件

公开 gate 只有三个：

1. `verify-static`：workspace Dart analyze/test、Rust format/lint/test，以及不依赖 candidate artifact 的源码契约检查。
2. `verify-integration`：当前 matrix target 的正式 native build、最终 artifact ABI、Flutter development path 和 external clean-host integration。
3. `verify-release-candidate`：candidate identity/digest、manifest/checksum、目标平台 clean-host runtime request、callback 和 body release。

CI 与 release workflow 必须调用完整 suite，不得通过一串 `dart test`、`cargo test` 或多个旧 workspace subcommand 自行拼出“近似 gate”。Suite 是否完整由 Catalog 测试证明。

## 原子检查

原子检查可以通过同一个 CLI 供本地定位失败，但它们只是诊断入口，不是独立 CI/release gate。新增原子入口必须复用 Catalog 中同一个 check definition，不得复制实现或重新声明依赖。

删除以下重叠或兼容式入口：

- 泛化但语义不完整的 `verify`
- `verify-artifacts` 对 `verify-artifact-consistency` 的 alias
- `verify-demo` 对 `verify-development-path` 的 alias

不保留 forwarding command。文档、workflow 和脚本在同一个 clean cutover 中切换到新 suite 或正式 check ID。

## GitHub Actions 职责

Workflow YAML 只负责：

- runner、permissions、secrets 和基础 toolchain setup
- 从 CLI 输出装载动态 matrix
- job dependency 和并发控制
- GitHub Actions artifact 上传/下载
- gate 全通过后的唯一 publication job

Workflow YAML 不负责：

- 定义支持 target 列表
- 决定 suite 包含哪些检查
- 复制 native build command、asset 文件名或 ABI symbol 清单
- 在 publication job 重新 build candidate

Workflow contract test 必须拒绝 direct check composition、手写 target list、旧 alias 和 gate 前 public release action。

## Native build 边界

`scripts/build_native_<platform>.sh` 和共享 build helper 继续拥有平台 toolchain 与 Cargo build 细节。Verification Catalog 调用这些脚本并验证输出，不在 Dart 或 YAML 中重写 Cargo manifest、target triple、copy path 或 SDK environment setup。

## 检查清单

- [ ] `workspace_tools.dart` 是否仍是薄 CLI，而不是聚合全部实现的单文件。
- [ ] 新检查是否只注册一次，并由 suite 引用同一个定义。
- [ ] CI/release workflow 是否只调用完整 suite。
- [ ] Actions matrix 是否来自 canonical native target matrix。
- [ ] YAML 是否没有复制 native build command、asset filename 或 target list。
- [ ] 本地原子检查是否明确属于诊断用途。
- [ ] 旧 `verify`/alias 是否已直接删除，且没有 forwarding wrapper。
- [ ] Candidate 是否只 build 一次，并由 verification 与 publication 消费同一 digest。

## Scenario: Catalog suite、coverage report 与本地 candidate 输入

### 1. Scope / Trigger

- Trigger: 修改 `scripts/verification/`、`scripts/workspace_tools.dart`、CI matrix、clean-host consumer 或 candidate gate。

### 2. Signatures

```text
workspace_tools.dart verify-static --execution <id> [--report-out <file>]
workspace_tools.dart verify-integration --execution <id> --fixture-url <url> --device <os>=<id>... [--report-out <file>]
workspace_tools.dart verify-release-candidate --execution <id> --candidate-dir <dir> --candidate-id <id> --candidate-digest <sha256> --sdk-ref <ref> --fixture-url <url> --device <os>=<id> [--report-out <file>]
workspace_tools.dart <suite> --aggregate-reports <dir>
workspace_tools.dart check <check-id> <typed inputs>
```

已发布版本回归只允许：

```text
workspace_tools.dart check released-consumer --execution <id> --repo-url <url> --ref <real-ref> --fixture-url <url> --device <os>=<id>
```

### 3. Contracts

- row report schema 固定包含 `schema_version=1`、`suite_id`、`execution_id`、`planned_check_ids`、`completed_check_ids`、`status`。
- aggregate mode 只读取 report，不执行任何 check、build 或 fixture materialization。
- candidate build-time environment 只允许 `NEXA_HTTP_NATIVE_CANDIDATE_DIR` 与 `NEXA_HTTP_NATIVE_CANDIDATE_REF`；设置 candidate directory 后缺 ref 或校验失败直接阻断，不 fallback 到 workspace/release source。
- `VerifiedCandidateSet` 保留原始 candidate directory 与 verified file handles；ABI/runtime consumer不得创建第二份 candidate set。
- `check` 复用 Catalog definition及其dependency，但不得输出 gate coverage report。
- 架构切换必须在同一任务删除旧 command、alias、forwarder、workflow、tests和docs；不得提交“先兼容、后清理”的中间态。

### 4. Validation & Error Matrix

- duplicate/unknown suite membership、unknown dependency或cycle -> Catalog构造失败。
- execution不覆盖required check -> planner失败，不允许host filter静默丢项。
- report缺失、重复、`status != passed` 或 planned/completed membership漂移 -> aggregate失败。
- candidate缺artifact、存在未知artifact、manifest/SHA256SUMS/实际bytes不一致 -> candidate set失败。
- 缺device、fixture URL、candidate identity/digest/SDK ref -> CLI usage失败。
- 平台toolchain或device缺失 -> suite失败，不得skip-as-pass。

### 5. Good/Base/Bad Cases

- Good: CI 从 `matrix --suite` 读取execution rows，每个row只运行一次完整suite并上传report，最终aggregate验证精确联合。
- Base: 本地用 `check native-abi` 定位问题，planner仍先运行同execution的`native-build` dependency。
- Bad: YAML手写Cargo/target/asset/check列表，或为旧命令保留deprecated alias/fallback。

### 6. Tests Required

- `fvm dart test test/verification`
- `fvm dart test test/native_abi_verifier_test.dart`
- `fvm dart analyze`
- `cargo fmt --all -- --check`
- `cargo clippy --workspace --all-targets -- -D warnings`
- `cargo test --workspace`
- `verify-static --execution static-linux` 必须通过真实Catalog runner。
- CI contract test断言YAML只调用matrix、完整suite和aggregate，且旧public release workflow不存在。

### 7. Wrong vs Correct

#### Wrong

```yaml
- run: cargo test --workspace
- run: dart run scripts/workspace_tools.dart verify-native-abi
```

#### Correct

```yaml
- run: dart run scripts/workspace_tools.dart verify-integration --execution "${{ matrix.execution_id }}" ... --report-out "reports/${{ matrix.execution_id }}.json"
```
