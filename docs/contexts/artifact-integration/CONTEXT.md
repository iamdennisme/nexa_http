# Artifact Integration Context

本上下文定义 Native Asset 从目标选择到 Host App 可运行状态的交付语言。它不定义 HTTP execution 或平台能力。

## Language

**Artifact Integration**:
为一个 Target Tuple 准备、验证、打包并证明 Native Asset 可运行的完整过程。
_Avoid_: Native build, release download

**Target Tuple**:
唯一选择 Native Asset 的目标身份，由 operating system、architecture 和可选 SDK variant 组成。
_Avoid_: Host platform, build machine

**Platform Carrier**:
Host App 显式依赖的 Flutter 平台包，负责把 Artifact Integration 接入标准 Flutter 构建和注册流程。
_Avoid_: Runtime API, native SDK

**Published Native Download Asset**:
发布系统提供的、与一个 Target Tuple 对应并带完整性信息的 native 文件。
_Avoid_: Release artifact, Native Asset

**Native Asset**:
为一个 Target Tuple 选定、通过 Flutter Native Assets 交付并由 runtime 使用的唯一 native binary。
_Avoid_: Native artifact, bundled library, materialized native library

**Artifact Materialization**:
把 workspace build output 或 Published Native Download Asset 转换为目标 Native Asset 的过程。
_Avoid_: Copy step, package mutation

**Clean-Host Consumer**:
只通过公开依赖和标准 Flutter 工具链集成 SDK 的全新 Host App。
_Avoid_: Demo App, workspace fixture

**Release Candidate**:
由明确 version 和 commit SHA 标识、尚未公开且内容与拟发布版本完全一致的一组 SDK packages 和 Published Native Download Assets。
_Avoid_: Debug build, public release

**Release Transaction**:
从 version/commit 请求、私有候选 staging、四平台 Release Gate 到创建公开 tag 和 Release 的一次原子发布过程。
_Avoid_: Tag-triggered build, post-release verification

**Release Gate**:
Release Candidate 公开前必须通过的全部 Target Tuple、ABI 和 Clean-Host Consumer 验证。
_Avoid_: Post-release verification, smoke build

**Verification Catalog**:
定义原子检查、完整验证套件及其 Target Tuple 覆盖关系的唯一清单。
_Avoid_: Workflow command list, duplicated CI matrix

**Supported Platform Set**:
一个 release 承诺同时支持的平台集合；当前集合是 Android、iOS、macOS 和 Windows。
_Avoid_: Available runner set, best-effort platforms
