# Recheck SDK principles

## Goal

按当前 Trellis/spec 原则对项目做一次复检，确认上一轮 SDK/package 边界、native build hook、clean-host consumer verification、release consumer gate 和 Trellis spec 文档没有明显违背项目契约的地方。

本任务默认是检查任务，不主动改代码。若发现 blocker 或高风险问题，先输出证据、影响面和建议修复方案，再由用户决定是否进入修复。

## Background

- 用户要求“再按照原则检测一次”。
- 当前无 active task，工作区在创建本任务前是 clean。
- 必须遵守 `.trellis/spec/guides/flutter-sdk-authoring-contract.md`：
  - 宿主 runtime 代码只 import `package:nexa_http/nexa_http.dart`。
  - 宿主依赖声明显式包含 `nexa_http` 和目标平台 `nexa_http_native_<platform>` carrier package。
  - 标准集成路径只能依赖 package dependency、`flutter pub get`、公开 Dart API 和标准 Flutter build/run。
  - build hook/native artifact 生命周期由 SDK 自持，不要求宿主手动改 native 工程或 shell profile。
  - `verify-release-consumer` 必须使用真实 release ref，不能使用 `vX.Y.Z` 占位符。

## Requirements

- 检查公开文档和示例是否保持主包 API import 边界，不暴露 `nexa_http_native_internal` 或 carrier runtime API。
- 检查 `packages/nexa_http`、demo、consumer fixture、workspace verification 的依赖声明是否符合“主包 + 目标平台 carrier package”的显式依赖原则。
- 检查 native build scripts 和 carrier hooks 是否仍满足 SDK 自持原则：不要求宿主手动复制 artifact、改 `Podfile`/Gradle/Xcode、设置 SDK path 或运行 SDK 专用脚本。
- 检查 release consumer 路径是否拒绝占位 ref，并能用真实 tag/ref 做干净宿主验证。
- 运行质量门禁命令，覆盖 Dart analyze/test、Rust fmt/test、workspace verify 和 consumer verification。
- 输出复检报告，按严重程度列出发现；若无问题，明确说明剩余风险和未覆盖平台。

## Out of Scope

- 不做功能重构。
- 不发布 release，不创建新 tag。
- 不默认修复发现的问题；除非用户在报告后要求继续修。
- 不把旧 release tag 的通过结果当成当前未发布工作区的 release blessing。

## Acceptance Criteria

- [x] PRD 记录本次复检范围、原则来源和不默认改代码的约束。
- [x] 读取相关 Trellis spec 和 Flutter SDK authoring contract。
- [x] 完成源码/文档/配置层面的边界检查。
- [x] 完成可在本机运行的验证命令，并记录任何无法覆盖的平台或 release gate 限制。
- [x] 最终输出 findings-first 报告，包含文件/命令证据。
- [x] 如果未发现 blocker，归档 Trellis task 并记录 session。

## Recheck Result

### Findings

- Medium: `docs/verification-playbook.md` 的 release validation 命令仍示例为 `NEXA_HTTP_RELEASE_REF=vX.Y.Z`。这和 Flutter SDK 编写契约中“release consumer 必须使用真实 ref，不能用 `vX.Y.Z` 占位符”的规则冲突；`scripts/workspace_tools.dart` 已正确拒绝该占位符，所以问题集中在文档示例误导。

### Confirmed Passes

- Runtime 示例和 app/demo 代码保持 `package:nexa_http/nexa_http.dart` 主包 import 边界。
- `packages/nexa_http/pubspec.yaml` 没有 `default_package` 隐式平台选择；demo 显式声明 `nexa_http` 和四个平台 carrier package。
- `buildExternalConsumerPubspecForHost()` 生成 `nexa_http` + host carrier package；`buildExternalConsumerMainDart()` 只 import 主包 API。
- Native build scripts/hook 满足 SDK 自持原则：macOS 脚本内部配置 `SDKROOT`/`-isysroot`，Rust target 安装有界超时，carrier hook 通过标准 Flutter build hook 协作。
- `.trellis/spec` 没有模板占位残留。

### Validation Evidence

- `fvm dart analyze` passed.
- `fvm dart test` passed.
- `packages/nexa_http_native_internal`: `fvm dart test` passed.
- `bash -n scripts/build_native_common.sh scripts/build_native_macos.sh scripts/build_native_ios.sh scripts/build_native_android.sh scripts/build_native_windows.sh` passed.
- `cargo fmt --all --check` passed.
- `cargo test --workspace` passed.
- `fvm dart run scripts/workspace_tools.dart verify-artifact-consistency` passed.
- `fvm dart run scripts/workspace_tools.dart verify-external-consumer` passed.
- `fvm dart run scripts/workspace_tools.dart verify-development-path` passed.
- `fvm dart run scripts/workspace_tools.dart verify` passed.
- `fvm dart run scripts/workspace_tools.dart verify-release-consumer` without ref failed as expected because HEAD is not exactly tagged.
- `NEXA_HTTP_RELEASE_REPO_URL=file://$(pwd) NEXA_HTTP_RELEASE_REF=v1.0.8 fvm dart run scripts/workspace_tools.dart verify-release-consumer` resolved the local git ref and reached macOS build, but failed while downloading GitHub release assets due network timeout.

### Residual Risk

- Current HEAD is not exactly tagged; a true current-release clean-host gate still must run after creating/pushing a release tag and publishing native assets.
- Remote GitHub release-consumer verification could not complete in this session because network access to `github.com` timed out.
- Windows and Android clean-host builds were not run locally; they are covered by CI/release runners rather than this macOS machine.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
