# Immutable release candidate transaction — Design

## 1. Problem statement

当前仓库已经具备canonical target matrix、release-profile native build scripts、candidate set verifier和四平台`verify-release-candidate` suite，但没有发布事务workflow。缺失的不是另一套verification，而是把“build once → private candidate → verify same bytes → optional publish”连接成一个不可旁路的Actions DAG。

物理约束是跨平台产物必须在Ubuntu、macOS、Windows分别构建；因此候选无法由单runner一次产生。最小机制是三个build fragments加一个唯一assembly job。Fragment不是candidate set，只有assembly输出的单一Actions artifact才是candidate authority。

## 2. Entry modes and authorization

同一`.github/workflows/release-native-assets.yml`拥有两类事件：

- `pull_request`：事务rehearsal。commit固定为PR head，version从checkout后的`packages/nexa_http/pubspec.yaml`读取，publish永久为false，所有job保持`contents: read`。
- `workflow_dispatch`：显式输入`version`、完整40位`commit_sha`、`publish`。`publish=false`运行完整候选与gate；`publish=true`才允许唯一publisher job取得`contents: write`。

Dispatch的信任顺序固定为：先checkout可信default branch，在该上下文只用Git校验raw SHA格式、commit存在与`origin/<default-branch>`ancestry；通过后才checkout批准commit并执行其中的Dart validator/build/gate/publisher代码。不能让待验证commit中的validator证明它自身可信。

不存在tag push、release event、workflow_run promotion或第二发布脚本。PR rehearsal只是同一DAG的不可发布测试入口，不是发布authority。

## 3. Transaction identity

事务输入规范化为：

```text
version: 2.0.0
tag: v2.0.0
commit_sha: 40 lowercase hex
candidate_id: gha:<run_id>:<artifact_id>
candidate_digest: sha256(sorted "<file-name>:<file-sha256>\n")
```

Version不得带`v`前缀，且必须与六个Dart package的`pubspec.yaml` version一致。Commit必须解析为同仓库commit并属于`origin/main`历史；PR rehearsal只要求等于PR head。

Manifest的`source_url`在assembly时直接写最终URL：

```text
https://github.com/<owner>/<repo>/releases/download/v<version>/<file-name>
```

## 4. Build and assembly data flow

```text
validate transaction
  ├─ build Android release fragment (3 targets, Ubuntu)
  ├─ build Apple release fragment (3 iOS + 2 macOS, macOS)
  └─ build Windows release fragment (1 target, Windows)
          ↓ private fragment artifacts
assemble-candidate (Ubuntu)
  → exact 9-file completeness/unknown-file rejection
  → manifest + SHA256SUMS generated once
  → candidate digest generated once
  → upload one immutable Actions artifact
          ↓ artifact_id + candidate_id + digest
4 blocking verify-release-candidate rows
          ↓ schema report artifacts
aggregate gate
          ↓ only dispatch publish=true
publisher
```

YAML只声明execution ID和runner orchestration；release targets、Rust triples、build script和filenames由canonical target matrix投影。Shared Dart helper按execution调用每个build script一次，显式传全部targets和release profile。

Assembly直接把fragment downloads merge到最终candidate directory；不再复制到第二个staging tree。Gate和publisher各自只下载同一个final Actions artifact一次。

## 5. Candidate verification contract

现有`verifyCandidateSet`继续streaming校验9个assets、manifest与`SHA256SUMS`。`source_identity`升级为：

```text
candidate:<candidate_id>:<candidate_digest>
```

Release-candidate aggregate除9 target/4 runtime platform覆盖外，必须拒绝任意row的candidate source identity不同。Android与Windows要求raw/identity相同；Apple继续以Mach-O UUID identity连接prepared与packaged payload。

## 6. Platform gates

- Android：`aosp_atd` x64 emulator，真实candidate Android asset runtime；clean-host main manifest在唯一release APK build前显式获得一条INTERNET permission，不依赖Flutter模板的debug/profile manifest。
- iOS：macOS runner启动simulator并运行candidate iOS row。
- macOS：macOS runner运行desktop candidate row。
- Windows：Windows runner运行candidate Windows row。

四行全部调用完整`verify-release-candidate` suite并上传schema report。Aggregate只读reports，不build、不重新materialize candidate。

## 7. Publisher contract

Publisher必须`needs` aggregate gate，并且条件精确为`workflow_dispatch && publish == true`。它执行：

1. 下载assembly输出的artifact ID。
2. checkout批准commit。
3. 重新验证version/package metadata、commit、candidate ID/digest、manifest base URL、checksums、9 assets完整性。
4. 再次查询tag和Release均不存在，防止dispatch后竞态。
5. 用已验证文件原名创建`v<version>` GitHub Release，target为批准commit；不build、不rename、不补文件。
6. 通过GitHub release asset API的remote digest核对每个上传文件。

若publisher在创建public state后失败，只清理由本次事务创建的release/tag；cleanup不是fallback或第二发布路径，而是事务补偿。Create API响应失败属于不确定结果，远端marker可能延迟可见，因此补偿不能在第一次false/false查询后退出：最多三轮中必须跨重试窗口确认稳定absence，期间一旦看到owned state或查询/删除错误就重置absence确认。Gate失败时publisher根本不启动，因此不会有tag、draft、prerelease或Release。

## 8. Failure and concurrency

- Workflow concurrency key包含version，`cancel-in-progress: false`；同version第二次事务排队并在existing-state preflight失败。
- Fragment缺失/unknown/duplicate asset、manifest/checksum drift、candidate digest mismatch、report identity drift、任一runtime失败均阻断aggregate。
- PR event结构上不能取得write permission或满足publisher condition。
- Diagnostics与reports使用private Actions artifacts，有限retention；它们不是外部发布产物或runtime fallback。

## 9. Performance contract

- 每个target只执行一次release Cargo build。
- 每个build script group每事务只启动一次。
- Assembly不创建第二份candidate tree；fragment download目录就是final candidate directory。
- Candidate verifier使用streaming digest cache，同一row不重复扫描大文件。
- Gate/publisher不进行native build；每个job只下载一次final candidate artifact。
- Android gate的clean-host APK只执行一次`flutter build apk --release`；path/candidate与released consumer共用fixture配置入口写入release main manifest网络权限，runtime直接`adb install`并启动`app-release.apk`，不使用debug VM attach，也不再用`flutter run`触发第二次Gradle assemble。

## 10. Rollout and rollback

本任务原子新增唯一release transaction workflow与release orchestration helper，并同步删除/拒绝任何旧tag authority。没有兼容workflow、forwarder或双轨期。

本任务只运行PR rehearsal和失败演练，`publish=false`；不创建public tag/Release。Rollback是整体revert transaction commit。
