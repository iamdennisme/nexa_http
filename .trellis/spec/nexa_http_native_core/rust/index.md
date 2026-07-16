# nexa_http_native_core Rust 规范

> 本目录记录共享 Rust native core 的开发约定。该 crate 位于 `native/nexa_http_native_core`，为所有平台 FFI crate 提供 HTTP runtime、FFI 数据结构、proxy 抽象和错误模型。

---

## 规范索引

| 规范 | 说明 | 状态 |
|------|------|------|
| [目录结构](./directory-structure.md) | crate 模块边界、进程内状态与持久化边界 | 已填充 |
| [错误处理](./error-handling.md) | `NativeError`、`NativeHttpError`、bootstrap error 和 FFI 传播 | 已填充 |
| [质量规范](./quality-guidelines.md) | FFI ownership、测试、格式化和禁止模式 | 已填充 |

---

## Pre-Development Checklist

- [ ] 变更 FFI struct、函数名或 ownership 时先读 [错误处理](./error-handling.md) 和 [质量规范](./quality-guidelines.md)。
- [ ] 变更模块布局、proxy abstraction、runtime 状态或持久化边界时先读 [目录结构](./directory-structure.md)。
- [ ] 准备新增日志或诊断输出时先读 [错误处理](./error-handling.md)。
- [ ] 跨 Dart SDK、platform carrier、Rust core 时同时读共享 [跨层思考指南](../../guides/cross-layer-thinking-guide.md) 和 [Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md)。

## Quality Check

- [ ] `cargo fmt --all --check` 通过。
- [ ] `cargo test -p nexa_http_native_core` 或等价 workspace Rust 测试通过。
- [ ] Dart FFI 侧调用方仍能按既有 ownership contract 释放 body、headers、error string。
- [ ] 没有新增 generic path probing、环境变量搜索或宿主可见 native workaround。
- [ ] 新增错误字段时同步 Dart decoder / mapper / tests。
