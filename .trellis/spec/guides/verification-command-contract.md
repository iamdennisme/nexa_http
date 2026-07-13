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

Android emulator是唯一允许的性能预热例外：`pre-emulator-launch-script`可以调用Catalog `check native-build --execution android-linux`，在emulator启动前填充同一workspace fingerprint cache。它不是独立gate；后续仍必须运行完整`verify-integration`，且suite内`native-build`只能命中同一File的fingerprint fast path，不得第二次Cargo build或复制prepared set。Workflow仍不得直接调用`build_native_*`。

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

- row report只接受`schema_version=2`，固定包含`suite_id`、`execution_id`、`planned_check_ids`、`completed_check_ids`、`status`、`prepared_artifacts`和`runtime_payloads`；schema v1直接拒绝，不提供兼容解析。
- `prepared_artifacts`每项包含canonical target tuple、完整Native Asset ID、绝对prepared file、raw`sha256`、`identity_sha256`与source identity。
- `runtime_payloads`每项包含同一target/asset identity、绝对packaged file、raw`sha256`、`identity_sha256`、`payload_count=1`及request/callback/body consumed/body released/client closed五个true字段。
- aggregate只读report并按canonical matrix校验9个target、Android/iOS/macOS/Windows四个平台、无重复/未知tuple，以及runtime和prepared的`identity_sha256`一致。Apple以Mach-O UUID集合连接身份；Android与Windows identity等于raw SHA。两端raw SHA始终保留用于审计。
- aggregate mode 只读取 report，不执行任何 check、build 或 fixture materialization。
- build hook不接收自定义`NEXA_HTTP_*`环境变量。candidate runtime consumer必须把`candidate_directory`与`candidate_ref`写入临时consumer pubspec的`hooks.user_defines.<carrier>`；absolute directory必须序列化为跨平台`file:` URI，不能直接写Windows盘符路径；缺任一项或校验失败直接阻断，不fallback到workspace/release source。
- integration native-build producer与workspace hook共享`.dart_tool/nexa_http_native/workspace/debug`及fingerprint sidecar；producer每个build-script group只启动一次，后续development/external consumer不得重复native build或复制一份prepared set。
- workspace fingerprint扫描必须排除native crate的`target/`、`build/`、`.dart_tool/`生成树，保持O(source inputs)而不是O(build outputs × target count)。
- `VerifiedCandidateSet` 保留原始 candidate directory 与 verified file handles；ABI/runtime consumer不得创建第二份 candidate set。
- `check` 复用 Catalog definition及其dependency，但不得输出 gate coverage report。
- 架构切换必须在同一任务删除旧 command、alias、forwarder、workflow、tests和docs；不得提交“先兼容、后清理”的中间态。

### 4. Validation & Error Matrix

- duplicate/unknown suite membership、unknown dependency或cycle -> Catalog构造失败。
- execution不覆盖required check -> planner失败，不允许host filter静默丢项。
- report缺失、重复、`status != passed` 或 planned/completed membership漂移 -> aggregate失败。
- proof缺字段、路径非绝对、digest格式错误、payload count不为1、lifecycle字段非true、target/asset/identity不匹配 -> row解析或aggregate失败。
- Windows `dumpbin /exports` 的 banner/path 可能包含以 `nexa_http_` 开头的临时目录名；symbol parser只接受工具输出行尾的symbol token，不得把`Dump of file <path>`当成unexpected export。
- Android emulator的`sys.boot_completed=1`不保证package manager已ready；Actions row必须先调用`scripts/wait_android_package_service.sh`有界等待`adb shell service check package`成功，超时直接失败，不得把后续install失败包装成SDK runtime失败。
- Android Actions row使用轻量`aosp_atd` image；三target native build通过Catalog在`pre-emulator-launch-script`完成，避免emulator与Cargo争抢CPU。完整suite随后复用workspace fingerprint cache；发现第二次native build或prepared copy即为性能contract失败。
- Android runtime必须复用external-consumer阶段唯一一次`flutter build apk`产生的APK；该build注入fixture URL，runtime只执行`adb install -t -r`、清空目标device logcat和`adb shell am start -W`，不得调用`flutter run`触发第二次Gradle assemble/debug attach。启动后只允许最多60次有界轮询同device的`flutter:I`日志；真实ATD冷启动曾在第30次之后才完成callback。仍无单一完整marker则失败，proof判定后best-effort force-stop fixture，cleanup失败不得冒充或覆盖proof结果。
- Android fixture不得在`print(NEXA_HTTP_RUNTIME_PROOF ...)`后主动退出，也不得用固定sleep推断日志已flush；验证端必须先观测完整marker。任何平台仍以marker内容而不是退出码判定通过。
- candidate缺artifact、存在未知artifact、manifest/SHA256SUMS/实际bytes不一致 -> candidate set失败。
- 缺device、fixture URL、candidate identity/digest/SDK ref -> CLI usage失败。
- 平台toolchain或device缺失 -> suite失败，不得skip-as-pass。

### 5. Good/Base/Bad Cases

- Good: CI 从 `matrix --suite` 读取execution rows，每个row只运行一次完整suite并上传report，最终aggregate验证精确联合。
- Base: 本地用 `check native-abi` 定位问题，planner仍先运行同execution的`native-build` dependency。
- Bad: YAML手写Cargo/target/asset/check列表，或为旧命令保留deprecated alias/fallback。

### 6. Tests Required

- `fvm dart test test/verification`
- `fvm dart test test/native_payload_identity_test.dart test/native_artifact_uniqueness_test.dart`
- `fvm dart test test/native_abi_verifier_test.dart`
- `fvm dart analyze`
- `cargo fmt --all -- --check`
- `cargo clippy --workspace --all-targets -- -D warnings`
- `cargo test --workspace`
- `verify-static --execution static-linux` 必须通过真实Catalog runner。
- CI contract test断言release workflow只有唯一transaction DAG、动态matrix、单一candidate artifact、四平台完整suite、report aggregate和唯一publisher；旧tag authority必须不存在。

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

## Scenario: Immutable Release Transaction

### 1. Scope / Trigger

- Trigger：修改 `.github/workflows/release-native-assets.yml`、`scripts/release_transaction.dart`、`scripts/release/`、candidate identity、publisher 或 native release 文档。

### 2. Signatures

```text
release_transaction.dart validate --mode pull-request --workspace-root <dir> --repository <owner/name> --commit-sha <40hex>
release_transaction.dart validate --mode dispatch --workspace-root <dir> --repository <owner/name> --version <stable-semver> --commit-sha <40hex>
release_transaction.dart build-fragment --workspace-root <dir> --execution <integration-execution-id> --output-dir <empty-dir>
release_transaction.dart assemble --candidate-dir <merged-fragment-dir> --version <stable-semver> --repository <owner/name>
release_transaction.dart verify-publisher --workspace-root <dir> --repository <owner/name> --version <stable-semver> --commit-sha <40hex> --candidate-dir <dir> --candidate-id <gha-id> --candidate-digest <sha256>
release_transaction.dart publish <verify-publisher全部参数>
```

Workflow 事件面固定为：

```text
pull_request
workflow_dispatch(version, commit_sha, publish)
```

### 3. Contracts

- `pull_request` 的 version 从六个 package pubspec 的唯一一致值派生，commit 必须精确等于 checkout PR head；它不要求未合并 head 已属于 `origin/main`，并且结构上永远不能运行 publisher。
- `workflow_dispatch` 的 version 必须是无 `v` 前缀、无前导零、无首尾空白的稳定 semver；commit 必须是无首尾空白的完整 40 位 SHA、精确解析且属于 `origin/main`。`publish=false`仍运行完整candidate与四平台gate。Raw dispatch input必须先映射到step env，再以quoted shell variable传入CLI；禁止把`${{ inputs.* }}`直接插入`run:`脚本。
- Dispatch必须先checkout可信default branch，并在任何supplied-commit Dart/pub/build代码执行前用Git校验raw SHA格式、commit object存在和`origin/<default-branch>`ancestry；通过后才checkout该SHA。Supplied commit中的Dart membership check只能作为纵深复核，不能作为自身的信任根。
- Fragment execution 只接受 canonical integration matrix 的 `android-linux`、`apple-macos`、`windows-x64` 投影。Targets、Rust triples、build scripts、runner 和 filenames 不进入 YAML/CLI 参数。
- Assembly 直接使用 fragment merge directory 作为最终 candidate directory。精确九个 asset 后只生成一次 manifest 与 `SHA256SUMS`，candidate digest 为排序后的 `<filename>:<file-sha256>\n` 的 SHA-256。
- Gate与publisher按精确artifact ID下载final candidate时必须启用扁平合并，让九个asset与两个metadata文件直接位于`candidate/`根目录；不得保留Actions默认的artifact-name子目录，也不得下载后再copy/rename一棵candidate tree。
- Final Actions artifact ID、`candidate_id=gha:<run-id>:<artifact-id>`、candidate digest 和批准 commit 必须原样传到 Android、iOS、macOS、Windows report。Prepared proof source identity 固定为 `candidate:<candidate-id>:<64位小写digest>`，四个 row 的每个 proof 必须完全相同。
- 全workflow默认`contents: read`；只有`publisher` job拥有`contents: write`，且条件同时满足`workflow_dispatch`、`publish=true`、aggregate success。
- Publisher只下载精确final artifact一次，重新验证version/commit/main membership/tag/release absence/candidate/manifest URL/checksum/文件覆盖，随后原名上传11个文件并核对GitHub asset API的`sha256:` digest。它必须用candidate ID/digest marker显式创建annotated tag ref与Release，分别记录ownership；失败时只清理本事务确认为owned的状态。Create响应不确定时，远端ownership可能延迟可见：最多三轮query/delete中必须跨重试窗口得到稳定absence，任何owned/error都重置确认；cleanup失败不得吞掉。不得build、rename、copy第二套candidate或重新生成metadata。
- 未声明CLI option直接usage error。禁止legacy/fallback/compatibility option、tag-triggered workflow、第二publisher、deprecated alias、forwarder和双轨中间态；release架构切换只能一次完成，rollback只能整体revert。
- 性能边界：每个build-script group每事务只执行一次；assembly不创建第二candidate tree；gate/publisher不native build；九个native asset digest复用verified candidate结果，publisher只额外读取两个小型metadata文件。

### 4. Validation & Error Matrix

- version带`v`、prerelease、缩写、数字前导零或首尾空白，或SHA非40位/含首尾空白 -> input parse失败。
- supplied commit在trusted Git preflight中不存在或不属于default branch历史 -> checkout supplied commit和任何仓库Dart代码执行之前失败。
- 六包version不一致、commit解析漂移、dispatch commit不属于main -> transaction preflight失败。
- tag或Release已存在 -> build/publish前失败；不得覆盖或复用旧public state。
- fragment output非空、缺文件、含unknown file或跨execution asset -> fragment失败。
- candidate缺/多asset、metadata已存在、manifest/checksum/bytes不一致或candidate digest漂移 -> assembly/gate/publisher失败。
- exact artifact下载落入`candidate/<artifact-name>/...`而不是`candidate/...` -> workflow contract失败；不得在verification中递归猜测或增加兼容目录探测。
- release-candidate source identity使用旧`candidate:<id>`、缺ID、digest非64位小写hex，或任一proof identity不同 -> aggregate失败；integration的`workspace` identity不受此格式约束。
- 任一平台report缺失、空文件、failed、lifecycle不完整或runtime/prepared identity不匹配 -> aggregate失败，publisher skipped。
- GitHub远端asset name/digest集合与本地11文件不完全一致 -> publish失败，并删除本事务ownership已确认的Release与tag；任一cleanup失败必须在最终错误中报告。
- ambiguous tag/Release create后ownership首次不可见、后续可见 -> cleanup继续重试并删除owned state；单次false/false不得判定成功。
- gate失败或`publish=false` -> 不创建tag、draft、prerelease或Release，只保留私有diagnostic artifacts。

### 5. Good/Base/Bad Cases

- Good：PR head构建三个fragment，原地assembly一个artifact，四平台按同一artifact ID/digest运行完整suite，aggregate通过，publisher skipped。
- Base：owner手动dispatch `publish=false`做完整release rehearsal，验证远端tag/release集合没有变化。
- Bad：tag push先创建public tag、publisher重新Cargo build、gate各自assembly、YAML手写target/filename，或保留旧release script作为备用入口。

### 6. Tests Required

- `fvm dart test test/release_transaction_test.dart test/release_transaction_cli_test.dart test/release_publication_gateway_test.dart`
- `fvm dart test test/verification/candidate_adapter_test.dart test/verification/report_test.dart test/verification/ci_workflow_test.dart`
- `actionlint .github/workflows/release-native-assets.yml`
- Workflow contract必须检查精确job set/needs DAG、唯一`contents: write`、dispatch trusted ancestry preflight早于supplied checkout/代码执行、动态matrix、artifact ID flow、exact artifact下载扁平落入candidate根目录、完整gate参数、report aggregate、publisher no-build/no-copy/no-regeneration和旧authority absence。
- PR rehearsal必须记录run ID，并证明四平台row、aggregate成功、publisher skipped、远端tag/Release/draft/prerelease集合无新增。
- Failure drill使用不可发布的无效input或`publish=false`路径，必须证明没有新增public state。

### 7. Wrong vs Correct

#### Wrong

```yaml
on:
  push:
    tags: ['v*']
steps:
  - run: cargo build --release
  - run: gh release create "$TAG" dist/*
```

#### Correct

```yaml
on:
  pull_request:
  workflow_dispatch:
    inputs:
      version: {required: true, type: string}
      commit_sha: {required: true, type: string}
      publish: {required: true, type: boolean}

publisher:
  if: ${{ github.event_name == 'workflow_dispatch' && inputs.publish == true && needs.aggregate-candidate.result == 'success' }}
  permissions:
    contents: write
```
