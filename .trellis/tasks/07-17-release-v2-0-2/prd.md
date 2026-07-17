# Release v2.0.2

## Goal

把 `v2.0.1` 之后已经完成并验证的兼容性架构改进，以新的 patch 版本 `v2.0.2` 安全推送到 `main`，通过 immutable release transaction 的四平台 candidate gate 后发布精确同一组 native assets、annotated tag 和 GitHub Release。

## Background

- 当前本地 `main` 为 `b2c61da57da9bd657ed7440953d9915985623f49`，相对 `origin/main` 的 `36a6096aaddc49a141a5118638c01a0463fc4d1e` ahead 12，worktree在任务创建前clean。
- 已发布稳定版本是 `v2.0.1`，tag和GitHub Release均存在；`v2.0.2` tag/Release均不存在。
- 六个release package当前版本均为`2.0.1`。Release validator要求它们与dispatch version完全一致，且dispatch commit是`origin/main`祖先。
- 待发布代码包含Trellis架构治理、proxy normalization集中化、Rust executor职责拆分和Dart native transport垂直模块收敛。Public Dart API、统一C ABI、failure taxonomy、ownership和carrier contract均保持兼容。
- 唯一发布入口是 `.github/workflows/release-native-assets.yml`；tag和Release是四平台candidate gate通过后的输出，不能手工预建或覆盖。

## Dependencies

- 遵守ADR-0009、ADR-0010、`.trellis/spec/nexa_http_workspace/tooling/verification-and-release.md`、`.trellis/spec/guides/verification-command-contract.md`和`.trellis/spec/guides/flutter-sdk-authoring-contract.md`。
- GitHub CLI已登录`iamdennisme`且token具有`repo`权限；repository default branch为`main`，当前main无branch protection。
- Release workflow拥有Android、iOS、macOS、Windows runner和唯一publisher权限面。

## Requirements

### R1. Prepare one consistent patch version

- 将 `nexa_http`、`nexa_http_native_internal` 和四个platform carrier的`pubspec.yaml`版本统一更新为`2.0.2`。
- 通过正式pub resolution更新tracked lockfiles，不手工伪造dependency graph，也不引入dependency升级噪音。
- 在`packages/nexa_http/CHANGELOG.md`记录本次兼容性内部重构，明确public API和ABI不变。

### R2. Keep published integration documentation current

- 将root英文/中文README和package README的可复制Git dependency示例更新为`v2.0.2`。
- 将项目分层契约的正式release示例更新为`v2.0.2`，并同步其governance contract test。
- `docs/architecture.md`中关于`v2.0.1` known-good审计和历史candidate provenance保持历史事实，不回写成尚未发布的证据。

### R3. Preserve product contracts

- 不修改public Dart exports/signatures、C header、generated FFI bindings、target matrix、artifact filenames、release workflow或runtime行为。
- 宿主依赖shape仍为`nexa_http`加目标platform carrier；runtime仍只import `package:nexa_http/nexa_http.dart`。
- 不新增mirror/offline/debug配置、宿主native工程步骤、fallback或第二发布入口。

### R4. Validate before remote mutation

- 运行release transaction/governance focused tests和最终`verify-static --execution static-linux`。
- 确认六包版本一致、README/spec版本引用准确、generated bindings和产品源码无意外diff。
- Push前重新fetch并验证远端main仍是本地历史祖先；只允许普通fast-forward push，禁止force push。

### R5. Run a non-publishing rehearsal first

- Release preparation commit push到`origin/main`后，以其完整40位SHA dispatch `version=2.0.2`、`publish=false`。
- 等待transaction input、三个fragment、single candidate assembly、Android/iOS/macOS/Windows gate和aggregate全部成功。
- Rehearsal后确认远端仍不存在`v2.0.2` tag、draft、prerelease或Release。

### R6. Publish only the gated transaction

- 只有rehearsal成功后，才能对同一commit SHA dispatch `publish=true`。
- 正式run必须四平台candidate gate和aggregate成功，唯一publisher才可创建annotated `v2.0.2` tag与stable GitHub Release。
- 验证tag指向批准commit，Release非draft/non-prerelease，11个发布文件及其digest proof完整。

### R7. Stop safely on failure

- 任一local check、push、rehearsal或candidate row失败都停止发布，不跳过平台、不手工创建tag/Release。
- `publish=false`或gate失败必须保持零public state；publisher失败必须验证transaction补偿已移除其owned tag/Release。
- 成功发布后禁止修改`v2.0.2` tag或assets；任何修复使用新patch版本。

## Acceptance Criteria

- [ ] AC1 (`R1`): 六个release package版本和tracked path lock resolution统一为`2.0.2`，CHANGELOG完整。
- [ ] AC2 (`R2`): 三份README和layering spec使用`v2.0.2`，历史`v2.0.1` provenance未被篡改。
- [ ] AC3 (`R3`): Public API、C ABI、bindings、target/artifact/release workflow均无行为性diff。
- [ ] AC4 (`R4`): Focused release tests、governance tests与最终`verify-static`全部通过。
- [ ] AC5 (`R4`): Release commit以普通fast-forward push到`origin/main`，远端精确包含批准SHA。
- [ ] AC6 (`R5`): `publish=false` rehearsal成功覆盖四平台和aggregate，且没有新增public tag/Release。
- [ ] AC7 (`R6`): `publish=true` run成功，`v2.0.2` tag/Release指向批准SHA并包含精确11个assets。
- [ ] AC8 (`R6`): Android、iOS、macOS、Windows runtime proof的request/callback/body consume/release/client close均为true且candidate identity一致。
- [ ] AC9 (`R7`): 发布证据写入任务工件，任务归档、journal记录、bookkeeping commits推送后worktree clean且无active task。

## Out Of Scope

- 新功能、public API变化、ABI变化或runtime修复。
- 修改release workflow、candidate matrix、artifact naming或publisher实现。
- 手工创建/移动tag、替换Release asset、跳过rehearsal或绕过失败平台。
- 发布到pub.dev；本项目继续使用Git dependency与GitHub Release native assets。
