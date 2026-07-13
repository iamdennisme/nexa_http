# Immutable release candidate transaction

## Goal

把 native release 改成显式 version + commit SHA 驱动的原子事务：候选资产私有 staging、四平台验证相同 bytes、全部成功后才创建 tag 与 GitHub Release，且发布阶段绝不重新构建。

本任务只安装并验证事务机制，不实际发布`v2.0.0`。PR rehearsal必须真实执行candidate build与四平台gate，但永远没有publication权限；只有owner显式dispatch并选择`publish=true`才构成未来的发布授权。

## Dependencies

- 依赖 `07-10-v2-public-http-api-cutover`、`07-10-verification-catalog-ci-suites` 和 `07-10-native-assets-four-platform-cutover` 全部完成。
- 必须使用前置任务定义的最终 API、唯一 Native Asset identity 和 `verify-release-candidate` suite。

## Requirements

- Release workflow 只接受显式 version 与 commit SHA，不再监听 public tag push。
- 同一workflow允许`pull_request` rehearsal，但该事件的version从已checkout package metadata读取、commit固定为PR head，并在结构上禁止publisher job运行；它不是第二发布入口。
- `workflow_dispatch`输入固定为`version`、完整40位`commit_sha`和`publish`。`publish=false`只执行完整candidate事务与gate；`publish=true`是唯一publication授权面。
- 各 target asset、manifest 和 `SHA256SUMS` 只生成一次，组成 immutable candidate set 并存入私有 GitHub Actions artifacts。
- Candidate build按canonical integration execution分为Android、Apple、Windows三个release-profile fragment；target列表、build script与filename不得在YAML手写。
- Assembly job把三个fragment直接下载到单一candidate目录，精确检查9个canonical assets，只生成一次manifest与`SHA256SUMS`，计算candidate digest，并上传一个不可变Actions artifact。不得在gate或publisher重新assembly/copy另一套candidate。
- Candidate set 记录可核对 digest；Android、iOS、macOS、Windows gate 下载并验证同一 set，不允许 runner 自行 rebuild 或替换文件。
- 四个平台report的`source_identity`必须包含同一candidate ID与digest；aggregate拒绝candidate identity漂移。
- 每个平台运行真实 clean-host runtime smoke，证明 dependency resolution、plugin registration、Native Asset loading、FFI client creation、fixture request、callback delivery 和 body release。
- 任一 gate 失败时只保留私有诊断 artifacts；不得创建 public tag、draft/prerelease 或 GitHub Release。
- 全部 gate 通过后，唯一 publisher job 下载同一 candidate set，为批准 commit 创建 version tag 与 Release；不 rebuild、不重命名、不补未验证 asset。
- Publication 权限只授予最终 job；workflow 必须防止 version/tag 已存在、commit/version 不一致或 candidate digest 漂移。
- 旧`tag_release_validation.sh`与tag-triggered workflow已经不存在；contract tests继续拒绝其恢复，不新增备用入口。
- Release metadata、manifest base URL、checksums 和 uploaded filenames 必须与 canonical target matrix 一致。
- Publisher在创建release前重新验证candidate、version、commit、tag/release不存在与asset completeness；上传后用GitHub release asset digest核对远端bytes。失败时清理本事务创建的release/tag，不得留下partial public state。
- 全workflow默认`contents: read`；只有`publisher` job在`workflow_dispatch && publish=true`时拥有`contents: write`。

## Acceptance Criteria

- [ ] Gate 失败演练不会产生 tag、Release、draft 或 prerelease，仅保留私有诊断。
- [ ] 所有四平台 job 报告相同 candidate-set identity，并通过 runtime smoke。
- [ ] Publisher job 的上传文件 digest 与已验证 candidate 完全一致，且 job 中没有任何 build command。
- [ ] Workflow 不再包含 tag-push trigger，旧 script 不再 push/create/reset tag。
- [ ] iOS 与其他三平台同等进入 blocking gate，不存在 allow-failure/skip 分支。
- [ ] Publication job 对 version、commit、existing tag/release、manifest/checksum 和 asset completeness 做失败优先验证。
- [ ] Workflow contract tests 证明 publication 依赖全部 gate，权限和 artifact flow 无旁路。
- [ ] PR rehearsal在当前feature head真实生成一次candidate set并通过Android/iOS/macOS/Windows aggregate，同时publisher job为skipped且远端无新tag/release。

## Out of Scope

- 实际发布 `v2.0.0`；最终外部发布仍需 owner 在 release-readiness review 后明确授权。
- 重新设计 public HTTP API 或 Native Assets packaging。
