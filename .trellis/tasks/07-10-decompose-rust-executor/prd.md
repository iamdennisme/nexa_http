# Decompose Rust executor

## Goal

在保持统一 C ABI、runtime behavior、error schema、cancellation 和 native ownership 不变的前提下，拆分 `native/nexa_http_native_core/src/runtime/executor.rs` 的多重职责，建立可独立验证的内部模块边界。

## Dependencies

- 以已发布并通过四平台验证的 `v2.0.1` 为行为基线；本任务不得改变公开 API、ABI、artifact contract 或发布事务。
- 若与 proxy normalization 同期推进，必须先固定共享 error/request/response contracts，避免两个任务同时移动相同逻辑。

## Requirements

- 保持 canonical 九个 `nexa_http_*` ABI symbol、struct layout、callback contract 和 artifact-level verification不变。
- 分离 runtime/client registry、inflight cancellation、request execution、FFI decode、FFI encode/result ownership 等职责。
- Public macro 与 platform FFI crate 仍只绑定 core facade，不感知内部模块拆分。
- 直接删除被替代的 executor 结构，不保留 forwarding facade 链或旧/新实现分支。
- 使用现有 Rust runtime/ownership/proxy tests，并补 module ownership/dependency tests。

## Acceptance Criteria

- [ ] `executor.rs` 不再同时拥有 registry、inflight、HTTP execution 和 FFI encode/decode 全部职责。
- [ ] Canonical ABI、generated bindings 和四平台 artifact symbol verification 无变化。
- [ ] Cancellation、request-body ownership、response-body ownership、error mapping 和 proxy refresh behavior 全部通过回归测试。
- [ ] 旧实现/forwarder 不存在，Rust fmt/clippy/test 与相关 integration suite 通过。

## Out of Scope

- 修改 public Dart API、C ABI 或 failure taxonomy。
- Proxy normalization 规则重设计。
