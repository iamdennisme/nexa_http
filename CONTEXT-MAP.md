# nexa_http Context Map

`nexa_http` 使用多个领域上下文维护统一语言。上下文描述领域概念，不替代两层项目架构、ADR 或实现 spec。

## Contexts

- [HTTP API](./docs/contexts/http-api/CONTEXT.md) — 宿主 App 创建和执行 HTTP 操作时使用的公开语言。
- [Native Transport](./docs/contexts/native-transport/CONTEXT.md) — Dart 与 native runtime 之间的执行、取消、回调和所有权语言。
- [Platform Capability](./docs/contexts/platform-capability/CONTEXT.md) — 平台网络能力、proxy state 和刷新语义。
- [Artifact Integration](./docs/contexts/artifact-integration/CONTEXT.md) — 目标选择、Native Asset 交付、carrier 和发布门禁语言。

## Relationships

- **HTTP API → Native Transport**：一个 `Call` 通过 Native Transport 执行；transport 细节不进入公开 HTTP 语言。
- **Native Transport → Platform Capability**：Native Transport 消费当前 `Platform Runtime State`，但不拥有平台能力发现。
- **Artifact Integration → Native Transport**：Artifact Integration 交付包含 `Uniform C ABI` 的唯一 `Native Asset`，供 Native Transport 使用。
- **Artifact Integration → HTTP API**：Artifact Integration 对宿主 runtime 代码保持隐藏；宿主只声明 SDK/carrier 依赖并使用 HTTP API。

架构决定记录在 [`docs/adr/`](./docs/adr/)，实现与验证契约记录在 [`.trellis/spec/`](./.trellis/spec/)。[架构索引](./docs/architecture.md) 说明它们的权威顺序、取代规则和 review provenance。
