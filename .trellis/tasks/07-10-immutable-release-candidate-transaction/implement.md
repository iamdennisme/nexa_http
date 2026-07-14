# Immutable release candidate transaction — Implementation Plan

## 1. Preconditions

- 读取`docs/adr/0009-gated-immutable-release-transaction.md`。
- 读取`.trellis/spec/guides/flutter-sdk-authoring-contract.md`、`verification-command-contract.md`、`project-layering-contract.md`和TDD policy。
- 复用canonical target matrix、typed build scripts、candidate verifier、schema reports和`verify-release-candidate` suite。
- 禁止创建public tag、draft/prerelease或GitHub Release；所有实际演练使用PR rehearsal或`publish=false`。

## 2. Ordered TDD slices

### Slice 1 — Transaction input and release metadata

1. RED：拒绝带`v`version、非semver、非40位SHA、package versions不一致、commit不可解析/不属于main历史。
2. RED：dispatch不得checkout或执行supplied commit中的validator后再证明其main membership；trusted default-branch preflight必须先完成。
3. GREEN：新增可信Git ancestry preflight，再checkout批准commit；聚焦release transaction module和薄CLI继续输出normalized version/tag/commit/base URL并做纵深复核。
4. RED：existing tag或Release任一存在失败；PR rehearsal commit/version解析与dispatch显式输入分离。
5. GREEN：实现read-only preflight，不创建任何远端状态。

### Slice 2 — Canonical release fragment builder

1. RED：execution到targets/build scripts/runner完全来自canonical matrix；YAML不得包含Rust triple或asset filename。
2. GREEN：抽取profile-aware grouped native build helper；release fragment每个build script一次invocation。
3. RED：fragment缺目标文件、含unknown文件或跨execution文件失败。
4. GREEN：输出精确platform fragment目录，不生成manifest/checksums。

### Slice 3 — Single candidate assembly

1. RED：三个fragment联合不等于9个canonical assets时失败。
2. GREEN：merge-download目录原地生成manifest与`SHA256SUMS`，base URL使用最终tag。
3. RED：candidate digest必须按排序filename+file digest生成，任意byte/name变化都会变化。
4. GREEN：输出candidate digest与artifact upload metadata；禁止第二candidate copy。

### Slice 4 — Candidate identity in reports

1. RED：candidate prepared proof缺candidate ID/digest或四row source identity不同时aggregate失败。
2. GREEN：`source_identity=candidate:<id>:<digest>`，aggregate精确比较。
3. RED：9 target、4 runtime platform、payload_count/lifecycle/identity任一漂移失败。
4. GREEN：保持schema与现有integration proof contract一致。

### Slice 5 — Workflow DAG and permissions

1. RED：workflow contract拒绝tag trigger、release event、publisher外`contents: write`、手写target/filename、direct build command、allow-failure与continue-on-error。
2. GREEN：新增PR rehearsal + workflow_dispatch transaction DAG，三个fragment、单assembly、动态四平台matrix、aggregate、唯一publisher。
3. RED：PR/publish=false不能满足publisher condition；publisher缺全部gate dependency失败。
4. GREEN：publisher job-level permission与条件收敛。

### Slice 6 — Four-platform candidate runtime

1. Android使用ATD emulator运行`candidate-android`；path/candidate与released fixture共用配置入口，在唯一一次release APK build前让main manifest包含恰好一条INTERNET permission，build注入fixture URL，runtime复用`app-release.apk`并通过`adb install`/`am start`启动，不依赖debug/profile manifest、不进入debug VM attach，也不调用`flutter run`二次assemble。
   - 零proof诊断必须报告fixture已到达的去重binding/mount/client/request/response/close phase和JSON failure，不再只返回marker count或依赖release Android不可见的stderr。
2. iOS启动simulator运行`candidate-ios`。
3. macOS运行`candidate-macos`。
4. Windows运行`candidate-windows`。
5. 四row下载同一artifact ID，传同一candidate ID/digest/sdk ref，并上传reports。
6. Aggregate验证same candidate identity、9 target、4 runtime lifecycle。

### Slice 7 — Publisher no-rebuild promotion

1. RED：publisher source出现Cargo/build script/manifest regeneration/rename即失败。
2. GREEN：publisher只下载candidate、重新验证、检查existing state并上传原文件。
3. RED：remote asset name/digest不等于candidate失败；partial publish cleanup必须覆盖create响应失败后ownership延迟可见的`false → true`序列。
4. GREEN：实现gh command adapter/脚本与marker-owned transaction compensation；最多三轮并要求稳定absence，不能把单次404当作清理完成。

### Slice 8 — Failure drill, docs and absence

1. 运行PR rehearsal，证明publisher skipped且四平台aggregate通过。
2. 运行显式无效input/failure drill，记录run ID，并用GitHub API证明tag/release/draft/prerelease集合未变化。
3. 更新README、verification playbook、ADR/spec，只描述唯一transaction。
4. 全仓搜索拒绝tag-push trigger、旧tag script、第二publisher、rebuild-after-gate与compatibility path。

## 3. Validation gate

```bash
fvm dart format --output=none --set-exit-if-changed <changed Dart files>
fvm dart analyze
fvm dart test test/verification
fvm dart test test/release_transaction_test.dart
fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux
fvm dart run scripts/workspace_tools.dart matrix --suite verify-release-candidate
```

GitHub Actions：

- PR rehearsal的Android/iOS/macOS/Windows candidate rows全部通过。
- aggregate gate通过并证明candidate identity一致。
- publisher job为skipped。
- failure drill失败且远端没有新增tag、Release、draft或prerelease。

## 4. Review gates

- `workspace_tools.dart`保持verification薄入口；release transaction使用独立聚焦module/entrypoint。
- Workflow不复制target matrix、build command或asset filenames。
- Candidate只assembly一次，gate/publisher不build、不rename、不重复生成manifest。
- Public runtime consumer仍只import`package:nexa_http/nexa_http.dart`，candidate通过formal`hooks.user_defines`注入。
- 当前任务不得实际选择`publish=true`。

## 5. Rollback

- 任一slice失败回到同一事实来源修复，不增加fallback workflow或旧tag入口。
- Rollback只能整体revert release transaction commit；不保留rehearsal-only或publisher-only中间态。
