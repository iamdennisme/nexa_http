# Release v2.0.3

## Goal

把 `v2.0.2` 之后已经合入并通过完整 CI 的 Android emulator 安装就绪恢复能力，以新的 patch 版本 `v2.0.3` 安全发布；发布必须经过 immutable release transaction 的非发布演练、四平台 candidate gate 和唯一 publisher，最终产出指向同一批准提交的 annotated tag、稳定 GitHub Release 与 11 个原生资产。

## Background

- 已发布的 `v2.0.2` annotated tag peel 到 `4baef319fbddcdb47722c5696ee6f7bacc7bda15`，对应 Release 为 non-draft、non-prerelease 且包含 11 个资产；该公开状态不可修改或复用。
- 当前 `main`、`origin/main` 均为 `567472f2cb04c6b6a3548fa00fc7cbce9831c07f`。该提交的 CI run `29570619943` 已通过 static、Android、Apple、Windows integration rows 和最终 `ci-gate`。
- `v2.0.3` tag 与 GitHub Release 当前均不存在。六个 release package 当前版本均为 `2.0.2`。
- `v2.0.2` 之后唯一功能性提交是 `42a4c042857d089bcbd5e05abe6d9536bab868d5`：失败的 verification command 保留不可变的 100 行 stdout/stderr tail，并且只有同时含 `PackageManagerInternal.freeStorage` 与 `null object reference` 的 Android install failure 才会对同一设备、同一 release APK 以 2 秒间隔最多尝试 3 次；成功后仍必须完成完整 runtime proof。
- 相对 `v2.0.2`，`packages/**/lib`、`native/`、C ABI、generated bindings、carrier native source、target matrix 和 release workflow 均无变化。

## Dependencies And Constraints

- 遵守 ADR-0009、ADR-0010、`.trellis/spec/nexa_http_workspace/tooling/verification-and-release.md`、`.trellis/spec/guides/verification-command-contract.md`、`.trellis/spec/guides/project-layering-contract.md` 与 `.trellis/spec/guides/flutter-sdk-authoring-contract.md`。
- 唯一发布入口是 `.github/workflows/release-native-assets.yml`。Tag 和 Release 是四平台 aggregate 成功后的输出，不能手工预建、移动或覆盖。
- GitHub CLI 当前以 `iamdennisme` 登录并具有 `repo` scope；远端默认分支为 `main`。

## Requirements

### R1. Prepare one consistent patch version

- 将 `nexa_http`、`nexa_http_native_internal` 和四个 platform carrier 的 `pubspec.yaml` 版本统一从 `2.0.2` 更新为 `2.0.3`。
- 通过正常 pub resolution 更新五个 tracked lockfile 中 `nexa_http_native_internal` 的 path resolution；不得改动恰好也为 `2.0.2` 的 hosted `node_preamble` 版本，不得引入 hosted dependency 升级噪音。
- 在 `packages/nexa_http/CHANGELOG.md` 顶部新增 `2.0.3`，只描述 verification failure diagnostics 与 Android emulator install boot-race 恢复，不宣称 public SDK/runtime 行为变化。

### R2. Keep current integration documentation accurate

- 将 root 英文/中文 README 和 `packages/nexa_http/README.md` 的可复制 Git dependency 示例更新为 `v2.0.3`。
- 将项目分层契约中的当前 release 示例更新为 `v2.0.3`，同步 `test/trellis_governance_test.dart` 的 literal assertion。
- 保留 `2.0.2` CHANGELOG、已归档任务、发布证据、Android hardening provenance 和 workspace journal 中的所有历史 `v2.0.2` 引用。

### R3. Preserve product and host-integration contracts

- 不修改 public Dart exports/signatures、runtime implementation、C header、generated FFI bindings、native source、target matrix、artifact filenames、carrier contract 或 release workflow。
- 宿主依赖 shape 仍为 `nexa_http` 加目标 platform carrier；runtime 仍只 import `package:nexa_http/nexa_http.dart`。
- 不新增 mirror/offline/debug 配置、宿主 native 工程步骤、fallback、第二发布入口或 pub.dev 发布。

### R4. Validate the exact release source before mutation

- 运行 Android readiness focused tests、完整 `test/verification`、release transaction/governance tests、`dart analyze` 和最终 `verify-static --execution static-linux`。
- 审查完整 diff，确认仅包含批准的 verification 增量、版本/lock/changelog/当前文档与 Trellis task 工件；历史证据和第三方版本保持不变。
- Release preparation commit push 后，等待该精确 SHA 的普通 CI 与 `ci-gate` 成功，再进入 release workflow。

### R5. Push only by fast-forward

- Push 前重新 fetch `origin/main` 并证明远端 main 是本地 main 的祖先；只允许普通 `main:main` fast-forward push，禁止 force push。
- Push 后确认 `origin/main` 精确解析到批准的 40 位 release commit SHA，并用该 SHA 完成本地 dispatch validation。

### R6. Run a non-publishing rehearsal first

- 对批准 SHA dispatch `version=2.0.3`、`publish=false`。
- Transaction input、三个 fragment、single candidate assembly、Android/iOS/macOS/Windows gate 和 aggregate 必须全部成功；四个平台必须完成 request/callback/body consume/body release/client close proof。
- Rehearsal 后确认远端仍不存在 `v2.0.3` tag、draft、prerelease 或 Release。

### R7. Publish only after rehearsal success

- 只有 R6 全部满足后，才能对同一批准 SHA dispatch `publish=true`。
- 正式 run 必须重新通过相同四平台 candidate gate 和 aggregate，唯一 publisher 才可创建 annotated `v2.0.3` tag 与 stable GitHub Release。
- 验证 peeled tag target、Release 状态、精确 11 个 asset names、GitHub asset digests、manifest 与 `SHA256SUMS` 一致。

### R8. Stop safely and preserve immutability

- 任一本地检查、push、CI、rehearsal 或 candidate row 失败都停止发布；不得跳过平台、手工建 tag/Release 或退回重发 `v2.0.2`。
- `publish=false` 或 gate 失败必须保持零 `v2.0.3` public state；publisher 失败必须验证 transaction compensation 已移除其 owned tag/Release，任何残留或所有权不明状态都阻断重试。
- `v2.0.3` 成功发布后不可修改 tag、Release 或资产；后续修复使用新的 patch 版本。

## Acceptance Criteria

- [x] AC1 (`R1`): 六个 release package 版本为 `2.0.3`，五个 tracked path lock resolution 为 `2.0.3`，hosted `node_preamble 2.0.2` 保持不变。
- [x] AC2 (`R1`, `R2`): CHANGELOG 准确描述唯一功能增量，三份 README、layering example 与 governance assertion 使用 `v2.0.3`，历史 `v2.0.2` 证据未被改写。
- [x] AC3 (`R3`): Public API、runtime/native source、C ABI、bindings、target/artifact/carrier/release workflow 没有计划外 diff。
- [x] AC4 (`R4`): Focused、完整 verification、release/governance、analyze 与最终 `verify-static` 全部通过。
- [x] AC5 (`R4`, `R5`): Release preparation commit 以普通 fast-forward push 到 `origin/main`，其完整 CI 和 `ci-gate` 成功，远端精确包含批准 SHA。
- [x] AC6 (`R6`): `publish=false` rehearsal 的 fragments、candidate、四平台 rows 与 aggregate 全部成功，publisher skipped 且没有新增 public state。
- [x] AC7 (`R7`): `publish=true` transaction 成功，`v2.0.3` annotated tag peel 到批准 SHA，Release 为 non-draft/non-prerelease。
- [x] AC8 (`R7`): GitHub Release 精确包含 9 个 native assets、manifest 与 `SHA256SUMS`，共 11 个 uploaded assets，远端 digest 集合与发布 metadata 一致。
- [x] AC9 (`R6`, `R7`): 每次 transaction 内四平台 reports 共用一个 candidate identity，且五个 runtime lifecycle 字段全部为 `true`。
- [x] AC10 (`R8`): 发布证据写入任务工件，任务归档、journal 与 bookkeeping commits 推送完成，最终 worktree clean 且无 active task。

## Out Of Scope

- 新功能、public API/ABI 变化或 product runtime 修复。
- 修改 release workflow、candidate matrix、artifact naming、publisher 或 Android retry policy。
- 手工创建或移动 tag、替换 Release assets、跳过 rehearsal/平台 gate，或重发/修改 `v2.0.2`。
- 发布到 pub.dev。
