# Centralize proxy normalization

## Goal

在不改变平台 proxy source ownership 与 public HTTP behavior 的前提下，把跨 Android、Windows、Apple adapter 重复的 URL/bypass normalization 规则收敛到 native core 的共享 primitives。

## Dependencies

- 以已发布并通过四平台验证的 `v2.0.1` 为行为基线；本任务不得改变公开 API、ABI、artifact contract 或发布事务。
- 与 `07-10-decompose-rust-executor` 无强制顺序，但不得并行移动相同 error/runtime source；每个任务开始前需重新检查重叠文件。

## Requirements

- 保持 `ProxyConfigSource`、`PlatformRuntimeState` 和 platform-owned OS discovery/state ownership 不变。
- Core 只拥有跨平台 normalization/canonicalization primitives；platform crates 只读取 OS raw values 并映射字段。
- iOS/macOS 继续共用 Apple parser，不把 SystemConfiguration/CoreFoundation 调用移入 pure parser/core。
- 通过跨平台共享 fixture 固定 URL、bypass、empty/direct/invalid 等语义。
- 删除平台重复 normalization 实现，不保留 wrapper 转发或并行规则。

## Acceptance Criteria

- [ ] Android、Windows、Apple adapter 消费同一 normalization primitives 和共享 fixtures。
- [ ] Platform crates 仍独占 OS discovery/runtime state，core 不直接调用平台 API。
- [ ] 重复 normalization/parser rules 被删除，无 forwarding wrapper。
- [ ] Core、Apple parser 和四平台 proxy tests 通过，public runtime behavior 无变化。

## Out of Scope

- Public proxy configuration API。
- 改变 polling/construction-boundary refresh policy 或支持平台集合。
