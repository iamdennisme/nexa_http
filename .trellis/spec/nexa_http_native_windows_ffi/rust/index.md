# nexa_http_native_windows_ffi Rust 规范

> Windows FFI crate 位于 `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi`，负责产出 Windows DLL 并把共享 core runtime 绑定到 Windows proxy source。

## 规范索引

| 规范 | 说明 | 状态 |
|------|------|------|
| [目录结构](./directory-structure.md) | 平台 FFI crate 布局、只读 registry 和状态边界 | 已填充 |
| [错误处理](./error-handling.md) | 平台 FFI 错误委托 core，registry 读取失败降级规则 | 已填充 |
| [质量规范](./quality-guidelines.md) | Rust ABI wiring、Windows registry adapter 和 crate-local tests | 已填充 |

## Pre-Development Checklist

- [ ] 修改 `src/lib.rs` C ABI wiring 时先读 [质量规范](./quality-guidelines.md)，保持共享 export macro。
- [ ] 修改 registry/proxy parser 时补充或更新 `tests/proxy_settings.rs`。
- [ ] 修改 registry 失败语义或诊断时先读 [错误处理](./error-handling.md)。
- [ ] 触达 carrier、artifact 或 release 边界时转到对应 Flutter/tooling owner，并阅读共享 [项目分层契约](../../guides/project-layering-contract.md)。

## Quality Check

- [ ] `cargo fmt --all --check` 通过。
- [ ] `cargo test -p nexa_http_native_windows_ffi` 通过。
- [ ] ABI wrappers 仍全部来自 core `export_nexa_http_ffi!`，proxy refresh 仍是 construction boundary。
