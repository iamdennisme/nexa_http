# ADR-0010: Verification Catalog owns gate composition

## 状态

Accepted

## 背景

当前 GitHub Actions workflow 直接拼接部分 Dart、Rust、ABI 和 consumer 命令，导致规范要求的 workspace Dart 检查与 Rust fmt/clippy/test 可以被遗漏。另一方面，把全部 orchestration 继续加入单个 `workspace_tools.dart` 会制造新的 tooling monolith，而删除所有单项检查又会降低本地诊断效率。

## 决策

`scripts/workspace_tools.dart` 作为唯一公开验证 CLI 和薄入口，`scripts/verification/` 中的 Verification Catalog 唯一定义原子检查、suite membership、inputs 和 target/runner matrix。

完整 gate 只有 `verify-static`、`verify-integration`、`verify-release-candidate`。CI/release workflow 只能调用完整 suite；本地可以通过同一 Catalog 运行原子检查进行诊断，但原子检查不是替代 gate。

Target/runner matrix 从 canonical native target matrix 生成，YAML 不维护第二份平台/架构列表。YAML 只拥有 Actions runner/toolchain setup、artifact transport、job dependency、permissions 和 publication。Native build command 继续由 `scripts/build_native_<platform>.sh` 拥有，Catalog 只调用并验证。

旧 generic `verify` 和 alias 直接删除，不提供 forwarding command。

## 后果

- 本地与 CI 使用同一 check definition，suite 完整性可以通过代码测试。
- Workflow 变成部署编排层，不再是质量规则来源。
- CLI implementation 必须拆分，避免把 CI 收敛问题转化成单文件维护问题。
- 本地仍能快速运行单项检查，但合并和发布只能由完整 suite 给出结论。

## 拒绝的替代方案

- 让 YAML 继续维护检查列表：拒绝，因为它已经与 Trellis spec 和本地命令发生漂移。
- 把所有逻辑放进一个 Dart 文件：拒绝，因为会复制 Rust executor 当前的单体问题。
- 只保留三个大命令、禁止单项诊断：拒绝，因为会显著拖慢本地 RED/GREEN 反馈。
- 引入 Make/Just 作为第二 CLI：拒绝，因为 Windows/Flutter workspace 已有跨平台 Dart orchestration，不需要新的命令 authority。

## 当前来源

- `scripts/workspace_tools.dart`
- `scripts/verification/catalog.dart`
- `scripts/verification/planner.dart`
- `test/verification/catalog_test.dart`
- `.trellis/spec/nexa_http_workspace/tooling/verification-and-release.md`
- `.trellis/spec/guides/verification-command-contract.md`
