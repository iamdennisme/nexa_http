# Native Transport Context

本上下文定义 Public Dart SDK 与 native runtime 之间的执行协议。它不定义公开 HTTP object model，也不负责交付 Native Asset。

## Language

**Native Transport**:
把 HTTP API 的执行意图转换为 native runtime 工作，并把结果转换回 HTTP API 的内部边界。
_Avoid_: Platform transport, public transport API

**Native Client Lease**:
Native Transport 持有的、代表一个已配置 native client 生命周期的句柄。
_Avoid_: HTTP Client, raw client ID

**Native Request ID**:
关联一次 native dispatch、Cancellation Handoff 和 Execution Callback 的稳定标识。
_Avoid_: Call ID, thread ID

**Cancellation Handoff**:
Call 的 Cancellation 从 Dart 侧转交给当前 native request 的过程。
_Avoid_: Client close, callback disposal

**Execution Callback**:
Native runtime 将一次请求的完成结果交还 Native Transport 的单次通知。
_Avoid_: Event stream, platform callback

**Callback Commit**:
Native Transport 与 native runtime 对一次 Execution Callback 已不可撤销地承诺交付的线性化点；此后 Cancellation 不能再成为 terminal winner。
_Avoid_: Callback start, Future completion

**Native Ownership**:
跨 Dart/native 边界的内存由哪一侧负责最终释放的规则。
_Avoid_: Garbage collection, implicit ownership

**Uniform C ABI**:
所有支持平台共同遵守的 native execution 与 memory ownership 二进制契约。
_Avoid_: Platform ABI, per-platform transport

**Rust Transport Core**:
实现共享 HTTP execution、client lifecycle、cancellation 和 result ownership 的 native runtime。
_Avoid_: Platform FFI adapter, carrier runtime

**Platform FFI Adapter**:
把 Rust Transport Core 与一个平台的 runtime state 绑定，并产出实现 Uniform C ABI 的 Native Asset。
_Avoid_: Platform transport, HTTP implementation
