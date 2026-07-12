# nexa_http_native_ios_ffi 后端规范

> iOS FFI crate 位于 `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi`，负责产出 iOS/simulator 动态库并把共享 core runtime 绑定到 iOS proxy source。

## 规范索引

| 规范 | 说明 | 状态 |
|------|------|------|
| [目录结构](./directory-structure.md) | 平台 FFI crate 布局和职责边界 | 已填充 |
| [数据库规范](./database-guidelines.md) | 本 crate 无数据库和持久化 | 已填充 |
| [错误处理](./error-handling.md) | 平台 FFI 错误委托 core，proxy 读取失败降级规则 | 已填充 |
| [质量规范](./quality-guidelines.md) | ABI、proxy tests、禁止重复 core 逻辑 | 已填充 |
| [日志规范](./logging-guidelines.md) | 不在平台库写运行时日志 | 已填充 |

## Pre-Development Checklist

- [ ] 修改 `src/lib.rs` C ABI export 时同步 core FFI 和 Dart bindings。
- [ ] 修改 `src/proxy_source.rs` 的 SystemConfiguration mapping 时更新 `tests/proxy_settings.rs`；修改纯解析规则时更新 `nexa_http_native_apple_proxy` tests。
- [ ] 修改 framework/dylib 命名或 target triple 时同步 canonical target matrix、iOS hook、typed build script、release manifest 和 verification tests；Podspec 不拥有 native artifact copy/preserve authority。

## Quality Check

- [ ] `cargo fmt --all --check` 通过。
- [ ] `cargo test -p nexa_http_native_ios_ffi` 通过。
- [ ] `cargo test -p nexa_http_native_apple_proxy` 通过。
- [ ] `packages/nexa_http_native_ios/test/build_hook_test.dart` 仍能解析和 materialize iOS artifact。
