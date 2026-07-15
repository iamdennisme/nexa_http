# Platform Capability Context

本上下文定义 native runtime 消费的平台网络能力语言。它描述当前状态和变化，不执行 HTTP Call。

## Language

**Platform Capability**:
由目标操作系统提供、会影响 HTTP execution 的平台网络能力。
_Avoid_: Platform feature flag, carrier feature

**Proxy Settings**:
当前生效的 HTTP、HTTPS、SOCKS 和 bypass 配置集合。
_Avoid_: Proxy source, environment proxy

**Proxy Source**:
读取目标操作系统原始 proxy configuration 的平台所有者。
_Avoid_: Proxy parser, Rust Transport Core

**Proxy Snapshot**:
某一时刻完整、不可变的 Proxy Settings 视图。
_Avoid_: Live proxy, proxy cache

**Proxy Generation**:
标识 Proxy Snapshot 是否发生语义变化的单调版本。
_Avoid_: Timestamp, refresh count

**Refresh Policy**:
决定何时重新读取 Platform Capability 的平台策略。
_Avoid_: Polling implementation, timer

**Platform Runtime State**:
Native Transport 可消费的当前平台能力视图，由 Proxy Snapshot、Proxy Generation 和 Refresh Policy 共同定义。
_Avoid_: HTTP client state, artifact state

**Bypass Rule**:
声明哪些目标地址不应使用 Proxy Settings 的匹配规则。
_Avoid_: No-proxy string, exception list
