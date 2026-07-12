# Verification Catalog and CI suites — Design

## 1. Problem statement

本任务解决的问题不是“再增加几个验证命令”，而是让每个 gate 只有一个可执行定义，并让本地、CI 和后续 release transaction 对同一执行计划达成一致。最小机制是：typed Catalog 定义事实，planner 生成去重后的 execution plan，runner执行计划，Actions 只承载 runner/setup/artifact transport。

## 2. Design principles

1. **一个事实来源**：check、suite、target coverage 和 execution projection 只在 Catalog/ canonical target matrix 定义一次。
2. **logical identity 与调度分离**：9 个 target 是产物身份，不等于 9 次平台 build。
3. **同一资源只生产一次**：build、fixture、inventory、digest 在一次 suite execution 中 memoize并复用。
4. **诊断与 gate 分离**：原子 check 可定位失败，但只有完整 suite 能形成 CI/release gate。
5. **clean cutover**：旧 command、旧 YAML composition、旧 workflow 和正向保护旧结构的 tests 同步删除。
6. **失败优先**：缺 toolchain、缺 target、candidate 不完整或 matrix 无覆盖都失败，不允许 skip-as-pass。

## 3. Module boundaries

```text
scripts/workspace_tools.dart
        |
        v
scripts/verification/cli.dart
        |
        +--> catalog.dart --------> checks/{static,integration,candidate}_checks.dart
        |
        +--> planner.dart --------> target_matrix.dart
        |                              |
        |                              v
        |                    canonical NexaHttpNativeTarget list
        |
        +--> executor.dart -------> process_runner.dart
              |   |   |
              |   |   +----------> reporter.dart
              |   +--------------> workspace_inventory.dart
              +------------------> consumer_fixture.dart / candidate_set.dart
```

### `workspace_tools.dart`

- 只调用 CLI parser/dispatcher。
- 不包含 check list、suite membership、`Process.run`、fixture templates、workspace copy 或 build command。
- 保留 `bootstrap` 作为非验证 workspace utility；它也应委托独立 module，不重新进入 CLI monolith。

### `model.dart`

定义稳定值对象：

- `VerificationCheckId`
- `VerificationSuiteId`
- `VerificationHost`
- `VerificationRunner`
- `VerificationExecutionId`
- `VerificationExecutionScope`
- `VerificationCheckDefinition`
- `VerificationExecutionPlan`
- `VerificationCandidateInput`
- `VerificationDiagnostic`

这些类型不依赖 GitHub Actions YAML；Actions JSON 是它们的 projection。

### `catalog.dart`

- 注册每个原子 check 一次。
- check definition 声明 suite membership、required inputs、supported execution groups、dependency IDs、produced/consumed resource keys 和 action。
- 构造时验证 duplicate ID、unknown dependency、cycle、unknown suite、duplicate membership、无 runner覆盖和必需输入不可满足。
- 暴露稳定排序，保证本地与 CI 诊断可复现。

### `planner.dart`

- 输入 suite ID、execution ID、target/candidate inputs 和当前 host。
- 解析 suite 成完整 check graph；不允许用 host filtering 静默丢 check。
- 对不能在当前 execution运行的 required check 返回明确错误；跨 runner suite 由 matrix rows共同覆盖。
- 按 `(checkId, normalized scope)` 生成 execution key并去重。
- 生成资源依赖和冲突键，使 build/fixture/candidate checks共享 producer output。

### `executor.dart` 与 `process_runner.dart`

- executor 执行 planner 已验证的 plan，不重新决定 suite membership。
- process runner 使用 `Process.start` 流式转发 stdout/stderr，保留 exit code、command和 elapsed time。
- 初始实现允许稳定串行执行；只有无 dependency 且 resource conflict key不相交的 checks 才能进入有界并发。
- fail-fast停止启动新的 dependent work，但仍完成已启动 process 的诊断收集。

### `workspace_inventory.dart`

- 单次扫描 workspace package manifests。
- 缓存 package kind、Flutter/Dart executable、test directory、Cargo workspace members 和 toolchain requirements。
- static suite、fixture materializer 和 report 共享同一 inventory，不重复递归扫描或解析 pubspec。

### `consumer_fixture.dart`

- 从 dependency graph 物化 external consumer所需最小 package closure，复用 `materialize_distribution.dart` 已有 filtered-copy思想或抽出的共享能力。
- 单次 suite中同一 dependency source + target execution只 materialize一次。
- development fixture、external workspace fixture和candidate fixture共享模板/runner，但保持依赖来源与验收语义独立。
- 已发布版本诊断通过Catalog `released-consumer` check复用consumer runner，显式要求repo URL/ref；它保留真实release回归能力，但不属于三个pre-merge/pre-publication suites。

### `candidate_set.dart`

- 只读打开 staged candidate directory，不复制 candidate artifacts。
- 校验显式candidate input、manifest、`SHA256SUMS`、canonical target completeness、文件名和 digest；不拥有release transaction metadata schema。
- digest 通过 stream计算；单次 run按规范化绝对路径 + expected identity memoize。
- 暴露 verified artifact handles给 runtime smoke，不重新 materialize第二份候选 bytes。

## 4. CLI contract

公开命令形状：

```text
workspace_tools.dart bootstrap
workspace_tools.dart verify-static --execution <execution-id>
workspace_tools.dart verify-integration --execution <execution-id>
workspace_tools.dart verify-release-candidate \
  --execution <execution-id> \
  --candidate-dir <path> \
  --candidate-id <opaque-id> \
  --candidate-digest <sha256> \
  --sdk-ref <ref>
workspace_tools.dart check <check-id> [typed inputs]
workspace_tools.dart matrix --suite <suite-id>
```

- matrix row执行suite时使用 `--report-out <path>` 输出coverage report；最终gate使用同一suite verb的 `--aggregate-reports <dir>` 模式验证所有row的union，aggregate模式不执行原子check。
- suite/check diagnostics写 stderr；正常人类报告也写 stderr，避免污染 machine output。
- `matrix` stdout只写单个 JSON object；成功时不夹杂日志。
- CI 只使用 `matrix` 和三个 suite verbs；不得使用 `check`。
- 不通过 environment variable隐式选择 target/candidate；敏感 token仍由 Actions环境提供，但不属于 Catalog事实。

## 5. Catalog check model

每个 `VerificationCheckDefinition` 至少包含：

```text
id
description
suites
dependencies
requiredInputs
supportedExecutionIds
producesResourceKeys
consumesResourceKeys
conflictResourceKeys
action
```

Suite membership 直接存在 check definition 中，Catalog反向构建 suite index。这样 check不会在一份 registry定义、又在另一份 suite list重复登记。Catalog tests对三个 suite使用明确 expected contract IDs，防止“实现与 expected都从同一错误列表派生”的同义反复测试。

## 6. Matrix and execution groups

### Logical targets

canonical `nexaHttpSupportedNativeTargets` 继续拥有：

```text
(targetOS, targetArchitecture, targetSdk, rustTargetTriple,
 sourceArtifactFileName, releaseAssetFileName, packagedRelativePath,
 buildScriptName)
```

本任务不在 Verification Catalog复制这些字段。

### Execution projection

Catalog拥有 runner/toolchain调度语义，并从 logical targets派生 execution rows。初始 integration rows：

| execution id | runner | logical coverage | build ownership |
|---|---|---|---|
| `android-linux` | `ubuntu-latest` | Android 3 targets | `build_native_android.sh` 一次平台 group build |
| `apple-macos` | `macos-14` | iOS 3 + macOS 2 targets | Apple正式 scripts；共享build producer，但iOS simulator与macOS runtime分别验收 |
| `windows-x64` | `windows-latest` | Windows x64 | `build_native_windows.sh` |

runner mapping是 verification调度语义；target list仍从 canonical matrix按 OS predicate派生。测试必须证明：

```text
union(execution.logicalTargets) == canonicalTargets
intersection(any two executions) == empty
```

不能把 Android/iOS每个 target展开成调用完整平台脚本的独立 job。若未来脚本支持真正独立且无重复工作的 target build，可修改 execution projection，但仍须通过 coverage和build-once tests。

### Suite-specific rows

- `verify-static`：Catalog根据 host-specific checks生成所需 runner rows；host-independent expensive checks只归属一个 canonical row，避免三平台重复。
- `verify-integration`：使用上述三个 build execution rows；`apple-macos` row内部包含独立的 `ios-runtime` 与 `macos-runtime` checks和报告，任一失败都会阻断该row，不能用一个macOS结果代替iOS证明。
- `verify-release-candidate`：从同一 target/execution authority投影 Android、iOS、macOS、Windows blocking rows；这些 rows消费同一个 candidate-set identity，不自行 build。

JSON row至少包含 `execution_id`、`runner`、`suite` 和必要的 target coverage metadata；不得包含 Cargo command或asset清单。

## 7. Execution and performance model

### Build once

```text
platform build producer
       |
       +--> artifact identity verification
       +--> ABI verification
       +--> development fixture
       +--> external clean-host fixture
```

producer以 execution ID + profile + SDK ref形成 resource key。所有消费者引用同一 producer result。planner发现重复 producer key时合并，不重新运行 shell script。

### Fixture once

external consumer fixture key由 dependency source、SDK ref和execution ID组成。物化只包含 consumer所需 packages与根级必要 manifests，不复制 `.git`、build、target、`.dart_tool`、Pods、临时目录、无关 docs或任务历史。多个 smoke checks使用同一 fixture directory；fixture cleanup由 run context exactly once负责。

### Candidate zero-copy verification

candidate input永远以只读文件句柄/路径传递。manifest/checksum和artifact digest读取原文件；runtime materialization如果 Flutter build chain必须生成自己的标准输出，只允许该构建链路所需的一次物化，不允许每个 verification check各复制一份candidate。

### Concurrency

- Actions execution groups提供主要跨平台并行。
- 单个 runner内，Dart/Rust纯静态 checks可以在资源键不冲突时有界并行。
- native build、同一 Cargo target dir、Flutter clean/build和fixture mutation默认串行。
- 并发不是绕过dedupe的理由；任何并行节点仍必须拥有不同 execution key。

## 8. Suite contracts

### `verify-static`

至少包含：

- workspace Dart analyze
- workspace Dart tests（每个 package一次）
- Rust fmt check
- Rust clippy workspace/all-targets
- Rust workspace tests
- generated bindings freshness
- FFI/source/architecture contracts
- workflow ownership/legacy absence contracts

host-specific crate check只分配给能真实运行它的 execution；host-independent checks只跑一次。

### `verify-integration`

每个 execution row：

1. 通过正式 platform build script产生 execution覆盖的 artifacts。
2. 对同一 artifacts执行 exact ABI verification。
3. 运行 development path。
4. 物化一次最小 external consumer closure并运行 clean-host build/runtime smoke；Apple row分别启动iOS simulator与macOS host smoke。
5. 分平台报告Android、iOS、macOS、Windows runtime proof，并报告每个 logical target的coverage与artifact identity。

缺 SDK/NDK/Xcode/MSVC等 prerequisite直接失败，并输出 expected setup action；删除现有 skip-as-pass行为。

### `verify-release-candidate`

本任务定义验证接口，不定义 release transaction 的最终 metadata schema。CLI显式接收：

```text
candidate directory
opaque candidate identity
expected candidate-set digest
SDK ref
execution/platform row
```

candidate directory至少提供现有manifest/checksum与canonical artifact files；后续transaction可以通过adapter增加version、commit和metadata，但不得要求Catalog兼容本任务私设的临时schema。验证顺序：

1. opaque identity、expected digest与显式输入完整。
2. manifest/checksum完整覆盖 canonical targets，无额外未知asset。
3. streaming digest与manifest、`SHA256SUMS`及expected candidate-set digest一致。
4. 当前 blocking row只消费已验证的candidate handles。
5. clean-host runtime smoke完成request、callback和body release。

本任务只建立本地 staged contract与suite；GitHub Actions私有 staging、promotion和publication由后续 transaction task接入。

## 9. Flutter SDK authoring mapping

| contract | design response |
|---|---|
| Host integration surface | fixture只声明主包 + carrier；runtime仅import `nexa_http.dart` |
| Hidden internal packages | fixture不得import internal/carrier runtime helper |
| Native lifecycle ownership | build hook/plugin/artifact preparation由SDK内部完成，Catalog只触发标准Flutter链路 |
| Formal configuration | suite输入显式提供execution/candidate identity，不要求修改宿主native工程 |
| Failure reporting | stage、target/execution、SDK/candidate identity、expected action、underlying error |
| Clean-host acceptance | pub get、registration、Native Asset、FFI client、request、callback、body release |

## 10. Workflow ownership and clean cutover

### CI

CI保留：checkout、FVM/Rust/platform toolchain setup、matrix bootstrap、job dependency和artifact transport。CI不得包含suite成员命令、Cargo build、target或asset lists。

固定job graph：

```text
catalog-matrices
  |-- output static_matrix JSON
  `-- output integration_matrix JSON
        |                 |
        v                 v
   static-suite      integration-suite
        \                 /
         `----> ci-gate <-'
```

- `catalog-matrices` 分别调用 `matrix --suite verify-static` 和 `matrix --suite verify-integration`，将完整JSON写入独立 `$GITHUB_OUTPUT`；command stdout不得含日志。
- matrix row只把 `execution_id` 传回对应完整suite command，并通过 `--report-out` 输出machine-readable coverage report artifact，包含suite ID、execution ID、planned check IDs、completed check IDs和status。
- `ci-gate` 依赖所有matrix rows成功并汇聚coverage reports，再分别调用 `verify-static --aggregate-reports <dir>` 与 `verify-integration --aggregate-reports <dir>`；suite planner验证reports union等于完整suite计划且无重复，YAML不重新列check membership。
- row失败或取消、空matrix、缺失coverage report都会阻断最终gate；不得使用 `continue-on-error` 或 skip-as-pass。

### Release workflow

当前 workflow公开发布发生在验证之前，且其架构无法在本任务范围内变成合格 immutable transaction。为避免保留第二 release authority，本任务直接删除 `.github/workflows/release-native-assets.yml` 及其旧 contract tests/docs入口。后续 release transaction task在Native Assets完成后创建唯一新workflow。

这段期间“没有release入口”是显式安全状态，不是兼容中间态；不得保留手工tag script或隐藏备用workflow。

## 11. Failure model

所有异常转换为 `VerificationDiagnostic`：

```text
stage
suiteId
checkId
executionId
host/runner
target tuple(s)
sdkRef
candidate identity/digest (when applicable)
expectedAction
underlying command/error
```

matrix/configuration错误在启动process前失败。process失败保留command、working directory、exit code和流式输出上下文。suite结束码非零即gate失败。

## 12. Migration and rollback

- 同一change切换CLI、Catalog、CI、tests和docs，并删除旧commands/workflow。
- 不保留deprecated alias、forwarder、旧YAML或双写Catalog。
- 回滚方式只有整体revert当前任务commit；不能通过重新打开旧入口作为运行时fallback。
- task未通过完整quality gate前不merge；后续Native Assets/release tasks只深化Catalog definitions，不另建parallel gate。
