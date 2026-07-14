# ADR-0009: Gated immutable release transaction

## 状态

Accepted

## 背景

当前 release workflow 由 tag push 触发，并在 clean-host consumer verification 之前创建 GitHub Release。即使把 verification job 移到 publish job 前面，public tag 仍已存在；同时如果验证后重新构建或重新生成文件，就不能证明发布的是被验证的 bytes。

## 决策

Release 不再由 tag push 触发，而是由明确 version 和 commit SHA 启动一次 Release Transaction。各 target 只构建一次，候选 native assets、manifest 和 checksums 作为一个 immutable candidate set 存入私有 GitHub Actions artifacts。

Android、iOS、macOS、Windows 的 ABI 和 clean-host runtime gate 必须消费这组候选 bytes，并核对其 identity/digest。任一 gate 失败时，不创建 public tag、draft/prerelease 或 GitHub Release，只保留私有 workflow diagnostics。

全部 gate 通过后，唯一 publisher job 下载同一个 candidate set，为批准的 commit 创建 version tag 和 GitHub Release。Publisher 不得 rebuild、替换、重命名或补充未验证的 asset。旧 tag-triggered workflow 和先创建 tag 的 release script 在同一个 clean cutover 中删除或重写，不保留第二发布入口。

唯一实现入口是 `.github/workflows/release-native-assets.yml`。`pull_request` 只运行不可发布 rehearsal；`workflow_dispatch` 只接受 `version`、完整 40 位 `commit_sha` 和 `publish`。Workflow 的 fragment matrix 与四平台 candidate matrix 都从 Verification Catalog 动态生成，YAML 不拥有 target triple、build script 或 asset filename。

`workflow_dispatch`不得先checkout或执行`commit_sha`中的仓库代码，再让该代码证明自身属于main。Workflow必须先checkout可信default branch，并在纯Git preflight中校验raw SHA格式、commit存在且属于`origin/<default-branch>`历史；只有通过后才checkout批准commit并运行Dart transaction validator。后续Dart preflight保留为纵深校验，但不是信任根。

Candidate identity 固定为 `candidate:gha:<run-id>:<artifact-id>:<candidate-digest>`。三个 build fragment 直接 merge 到最终 candidate directory，manifest 与 `SHA256SUMS` 只生成一次；gate 与 publisher 都按精确 artifact ID 各下载一次，不创建第二棵 candidate tree。

Publisher 通过单一 release transaction CLI 重新执行 preflight、原名上传和 GitHub Release asset digest 核对。它先创建包含 candidate ID/digest 事务 marker 的 annotated tag object 与精确 tag ref，再创建包含同一隐藏 marker 的 Release；tag 与 Release 分别记录 ownership。若创建 public state 后上传或 digest proof 失败，只补偿删除 ownership 已确认属于本事务的 Release 与 tag。由于create响应失败后远端状态可能延迟可见，单次“不存在”不能结束补偿；最多三轮ownership查询/删除中必须得到跨重试窗口的稳定absence，任一ownership/error都会重置确认。cleanup失败必须成为显式错误。补偿不是 fallback 或第二发布入口。

## 后果

- Tag 与 GitHub Release 是验证成功后的输出，不再是验证输入。
- “验证什么就发布什么”通过 candidate digest、manifest/checksum 和 no-rebuild promotion 形成可执行契约。
- 发布操作需要显式提供 version 和 commit SHA，增加少量操作步骤，但失败不会留下误导性的 public release state。
- Private workflow artifacts 是发布事务内部 staging，不是 runtime fallback、兼容 packaging path 或新的对外产物。
- Release 架构变更必须一次切换完成；不得保留 deprecated alias、forwarder、兼容参数、旧 workflow 或“先双轨再清理”的中间态。
- 性能边界可执行：每个 build-script group 每事务只启动一次；assembly 不复制第二棵 candidate；gate/publisher 不 native build；publisher只额外 hash 两个小型 metadata 文件，九个大 asset 复用 candidate verifier 已得到的 digest。

## 拒绝的替代方案

- 继续 tag-triggered、只把 consumer jobs 前移：拒绝，因为 tag 仍在 gate 之前公开。
- 先发布 draft/prerelease 再验证：拒绝，因为 candidate verification 不需要创建 release state，而且容易被误认为可消费版本。
- Gate 通过后重新 build：拒绝，因为最终 bytes 不再是实际通过验证的 candidate。
- 保留旧 tag script 作为备用入口：拒绝，因为会形成第二 release authority。
