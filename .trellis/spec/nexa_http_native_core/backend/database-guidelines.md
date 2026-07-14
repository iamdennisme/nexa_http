# 数据库规范

本项目 native core 当前没有数据库、ORM、migration、table 或持久化存储层。

## 规则

- 不要在 `native/nexa_http_native_core` 中引入 SQLite、文件数据库、ORM、migration 目录或后台持久化缓存。
- runtime 状态保持进程内存模型：client registry、in-flight request、proxy snapshot 和 Tokio runtime 均由 `runtime/` 管理。
- 如果需要跨请求共享状态，优先放在明确的 runtime struct 中，例如 `ClientRegistry`、`ManagedProxyState`，并用测试证明生命周期。
- 如果未来确实需要持久化，必须先创建 Trellis 任务并同步 ADR/spec，定义数据所有权、清理策略、隐私影响和跨平台路径。

## 真实例子

- `native/nexa_http_native_core/src/runtime/client_registry.rs`：client 只在进程内注册和移除。
- `native/nexa_http_native_core/src/runtime/managed_proxy_state.rs`：proxy state 通过内存 snapshot 和 refresh mode 管理。
- `native/nexa_http_native_core/tests/proxy_runtime.rs`：用测试 source 模拟 proxy state，不依赖外部数据库。

## 禁止模式

- 不要把 native artifact manifest、release metadata 或 platform package 配置写入 core crate 的本地数据库。
- 不要为了测试方便引入临时持久化文件；测试应该使用 in-memory fake、fixture server 或临时目录中的显式文件。
