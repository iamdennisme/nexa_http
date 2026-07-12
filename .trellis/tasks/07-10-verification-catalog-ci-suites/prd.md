# Verification Catalog and CI suites

## Goal

建立唯一、模块化、可本地执行的 Verification Catalog，让本地、Pull Request CI 和后续 release transaction 复用同一份 check definitions、suite membership、执行分组和动态 matrix；同时一次删除 workflow、CLI alias、测试和文档中的第二事实来源。

## Background

- 当前 `scripts/workspace_tools.dart` 同时拥有 CLI dispatch、suite composition、process orchestration、workspace copy、consumer fixture 和 host matrix，已经形成 775 行 tooling monolith（`scripts/workspace_tools.dart:22-82,85-186,194-399,423-765`）。
- generic `verify` 会重复执行 `nexa_http_native_internal` tests 和 demo tests；CI 又在 Ubuntu、macOS、Windows 三个平台重复拼接 ABI、artifact、development 和 external-consumer checks（`scripts/workspace_tools.dart:155-220,233-270`；`.github/workflows/ci.yml:30-49,61-72,87-96`）。
- CI/release YAML 手写 Rust target、Cargo manifest/build command、asset filename 和 gate 序列；现有 contract tests 还在正向保护这些重复事实来源（`.github/workflows/release-native-assets.yml:14-105`；`test/workspace_demo_and_consumer_verification_test.dart:24-69`；`test/release_workflow_layout_test.dart:5-13`）。
- canonical native target matrix 已定义 9 个 logical targets，但 Android 与 iOS build scripts 各自一次构建整个平台 target group；Actions 若按 9 个 target 逐行调度会重复完整 build（`packages/nexa_http_native_internal/lib/src/native/nexa_http_native_target_matrix.dart:54-153`；`scripts/build_native_android.sh:69-111`；`scripts/build_native_ios.sh:18-48`）。
- external consumer 当前为每次检查递归复制大部分 workspace，再执行 git init/commit；同一 suite 中重复创建会造成无关 I/O 和磁盘放大（`scripts/workspace_tools.dart:295-323,448-518`）。
- 现有 release workflow 在 consumer gate 之前创建公开 Release，无法作为后续 immutable candidate transaction 的临时入口；按 clean cutover 原则，本任务直接删除该 workflow，不保留 fallback。后续 `07-10-immutable-release-candidate-transaction` 在 Native Assets cutover 完成后创建唯一正式发布入口。

## Dependencies

- `07-10-v2-public-http-api-cutover` 已完成；development/external/candidate fixtures 必须只使用最终 v2 public API。
- 完成本任务后，`07-10-native-assets-four-platform-cutover` 和 `07-10-immutable-release-candidate-transaction` 必须把新增 gate 深化到同一 Catalog，不得在 YAML 或新脚本中另写检查序列。

## Requirements

### R1. 单一 CLI 与模块边界

- `scripts/workspace_tools.dart` 保持唯一公开 CLI，但只负责参数解析、输入验证和 dispatch。
- Catalog、planning、execution、process streaming、workspace inventory、consumer fixture、candidate validation、matrix projection 和报告拆入 `scripts/verification/` 下的聚焦模块。
- `bootstrap` 可以继续作为非验证 workspace utility；验证入口只允许三个完整 suite、Catalog matrix 输出和 Catalog 原子诊断。

### R2. Catalog 是唯一事实来源

- Catalog 唯一定义 check ID、执行函数、suite membership、依赖/产物、host/target/toolchain/candidate inputs、execution key 和诊断元数据。
- check ID 必须唯一；suite 引用未知 check、重复 membership、无 runner 覆盖或输入不完整时必须失败，不得静默过滤。
- 原子诊断必须通过同一 Catalog definition 执行，不得保留另一份 wrapper 或 command composition。

### R3. 三个完整 suite

- `verify-static` 覆盖 workspace Dart analyze/test、Rust fmt/clippy/test 和不依赖 candidate artifact 的源码/生成物/ABI contract checks。
- `verify-integration` 覆盖正式 native build script、最终 artifact ABI、development path 和 external clean-host integration。
- `verify-release-candidate` 接收本地 staged candidate set、opaque candidate identity/digest 与 execution input，验证 artifact completeness、streaming digest、manifest/checksum、目标平台 clean-host runtime request、callback 和 body release。Candidate metadata schema、version/commit transaction binding 由后续 release transaction task拥有，本任务不得提前固定中间协议。
- CI 和后续 release workflow 只能调用完整 suite；本地原子 check 仅用于诊断，不能作为 gate 结论。

### R4. Logical target 与 execution group 分离

- canonical native target matrix 继续拥有 9 个 logical target tuple、Rust target、source artifact、release filename 和 packaging identity。
- Catalog 从 canonical targets 派生 execution groups；不得把每个 logical target机械变成一个完整 build job。
- 初始 build execution groups 至少覆盖 Android/Ubuntu、Apple/macOS 和 Windows/Windows，并证明 canonical target union 恰好覆盖一次；Apple build producer可以共享，但 iOS simulator与macOS clean-host/runtime checks必须作为两个独立平台验收节点分别报告。`verify-release-candidate` 从同一事实来源投影 Android、iOS、macOS、Windows 四个平台 blocking rows。
- Native build/toolchain/Cargo/path 细节继续由 `scripts/build_native_<platform>.sh` 拥有；Catalog 只传递正式 target/group input、调用脚本并验证输出。

### R5. 执行去重与性能预算

- planner 以稳定的 `(check ID, normalized execution scope)` 生成 execution key；单次 suite 中同一 key 最多执行一次。
- 一个平台 build group 每次 suite 最多 build 一次，后续 ABI、artifact 和 consumer checks 复用同一产物 identity；禁止按 target 重跑整个平台 build。
- workspace package discovery、pubspec/toolchain classification 和其他只读 inventory 在单次 run 中只计算一次。
- consumer fixture 只物化最小 package dependency closure，并在单次 suite 中 lazy-create、复用一次；不得为每个 check 或 target 重复复制 workspace。
- candidate artifacts 原地只读验证；digest 使用流式读取并在单次 run 内按 artifact identity 缓存，不得为了不同 check 重复复制完整文件。
- process runner 必须流式转发 stdout/stderr，避免 `Process.run` 全量缓冲长时间 Cargo/Flutter 输出。
- 并发仅用于无依赖且无资源冲突的 checks；workspace mutation、同一 build directory、同一 fixture 或同一 candidate resource 必须用 execution/resource key 串行化。

### R6. CLI 与 machine-readable contract

- 完整 suite、原子诊断和 matrix projection 必须使用稳定的 typed arguments；target、execution group 和 candidate inputs 不允许依赖隐式环境猜测。
- matrix stdout 只输出 machine-readable JSON，diagnostics 写 stderr；schema 由 contract test 固定。
- 失败诊断至少包含 stage、suite/check ID、runner/host、target tuple 或 execution group、SDK ref/candidate identity、expected action 和 underlying error。
- 本地缺失平台 prerequisite 必须失败；不得 skip 后把 suite 报告为通过。

### R7. Flutter SDK clean-host boundary

- fixture 依赖必须包含 `nexa_http` 与目标平台 carrier package；runtime code 只 import `package:nexa_http/nexa_http.dart`。
- integration/candidate smoke 必须覆盖标准 `flutter pub get`、plugin registration、Native Asset loading、FFI client creation、真实 fixture request、callback delivery 和 body release。
- fixture 不得 import `nexa_http_native_internal`、carrier runtime API 或要求宿主修改 native 工程。
- 已发布版本的 release-consumer regression保留为 Catalog 原子诊断 check，显式接收 repo URL/ref并继续验证真实 tag/ref解析；它不是 pre-publication gate，也不得保留旧 top-level command。

### R8. Clean cutover

- 直接删除 generic `verify`、`verify-artifacts`、`verify-demo`、对应 forwarding functions，以及所有旧 top-level atomic verification entrypoints；原子诊断统一迁移到 Catalog check selector，不保留 deprecated alias。
- 同一次改动更新 CI、tests、README/spec/playbook 引用；全仓搜索旧 command/symbol/path 必须无残留。
- CI YAML 改为加载 Catalog JSON matrix 并调用完整 suite，不得直接拼 `dart test`、`cargo test`、native build command、target list、asset filename 或 suite member list。
- 直接删除当前不安全的 `release-native-assets.yml`；在后续 immutable release transaction 完成前不提供备用发布入口。

## Acceptance Criteria

- [ ] Catalog tests 证明 check ID 唯一、三个 suite membership 完整、未知/重复/无覆盖配置失败，且没有静默漏项。
- [ ] `workspace_tools.dart` 是薄 CLI；source contract 拒绝其拥有 `Process.run`、fixture materialization、native build 或 suite composition 实现。
- [ ] planner tests 证明同一 execution key 只执行一次，Android/Apple/Windows build group 不因多个 logical targets 重复 build。
- [ ] inventory、fixture、candidate digest instrumentation 证明单次 suite 中各自只准备/读取一次；candidate 与 native artifact 不发生检查间完整复制。
- [ ] dynamic Actions matrix 与 canonical native target matrix 双向一致，每个 target 恰好属于一个 execution group，JSON schema 可由 Actions 直接解析。
- [ ] `verify-static` 在 Catalog 定义的 runner 组合覆盖全部 Dart/Rust required checks；重复 workspace tests 不再跨 check 或 runner无意义重跑。
- [ ] `verify-integration` 在 Android、Apple 和 Windows build execution groups覆盖正式build/ABI，并分别证明 Android、iOS、macOS、Windows 的 development/external clean-host runtime行为；缺 prerequisite明确失败。
- [ ] `verify-release-candidate` 能针对本地 staged candidate 输入验证 identity、digest、manifest/checksum 和 runtime-smoke contract，并输出完整 issue-ready diagnostics。
- [ ] CI workflow 只加载 Catalog matrix并调用完整 suite；contract test 拒绝 direct gate composition、手写 target/asset/build command 和旧 command。
- [ ] 旧 release workflow、旧 CLI commands/aliases、forwarding functions、旧 tests 与旧文档入口全部删除，无 fallback、deprecated alias 或双轨中间态。

## Out of Scope

- 四平台 Native Assets/CodeAsset authoritative packaging 和 runtime loader 的 clean cutover本身。
- GitHub Actions 私有 candidate staging、version/commit dispatch、tag creation、Release publication 和 promotion transaction。
- 实际创建任何 public tag、draft、prerelease 或 GitHub Release。
