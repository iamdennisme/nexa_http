# Deepen Dart native transport module

## Goal

在保持 v2 public API、C ABI、ownership/copy budget 和 runtime behavior 不变的前提下，把当前互相穿透的 `data/sources`、`native_bridge`、`internal/transport` 收敛为单向依赖的垂直 native-transport module。

## Dependencies

- 以已发布并通过四平台验证的 `v2.0.1` 为行为基线；本任务不得改变公开 API、ABI、artifact contract 或发布事务。
- 若发现 external contract defect，必须拆出独立修复任务，不得把行为变化隐藏在本次结构重构中。

## Requirements

- 保持 public API、typed failure taxonomy、Call cancellation、Request/Response body ownership和 copy counts 完全不变。
- 消除 `internal/transport ↔ data/sources` 目录级反向依赖，建立一个垂直 feature boundary。
- Lease lifecycle、request mapping、FFI encode/decode、pending registry、response mapping 和 cancellation ownership 各有单一 owner。
- 直接移动/删除旧结构，不保留 forwarding imports、barrel alias 或新旧目录双轨。
- 使用现有行为/ownership tests 作为重构保护，并增加 dependency-direction contract test。

## Acceptance Criteria

- [ ] Dart native transport 形成单向垂直模块，旧目录/forwarder 不存在。
- [ ] Public API、ABI、failure mapping、cancellation race 和 body ownership/copy tests 无行为变化。
- [ ] Dependency contract test 拒绝重新引入反向目录依赖。
- [ ] Full relevant verification suites 通过。

## Out of Scope

- Public API 再设计、Rust executor 拆分、Native Assets 或 release workflow。
