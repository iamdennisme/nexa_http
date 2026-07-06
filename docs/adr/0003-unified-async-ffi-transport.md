# ADR-0003: unified async FFI transport

## 状态

Accepted

## 背景

`native transport` 是 Dart request/call execution 到 Rust HTTP execution 的路径。所有支持平台都通过 platform carrier 加载 native library，并通过 C ABI 调用 Rust runtime。

历史设计文档 `docs/superpowers/specs/2026-03-29-unified-async-ffi-transport-design.md` 记录了统一 request pipeline 的方向：Dart 映射 request、分配 FFI args、调用 `nexa_http_client_execute_async`，Rust core 执行请求并通过 callback 返回 `NexaHttpBinaryResult`。

平台差异应该存在于 native library location、packaging、plugin registration、proxy state 和 platform capability access，而不是 request execution model。

## 决策

所有支持平台使用一个 unified async FFI transport pipeline。

当前 platform FFI crates 统一 export `nexa_http_*` C ABI symbols，Dart native transport 通过同一套 request/response/callback/ownership contract 调用它们。

平台不得定义自己的 request transport model。平台差异留在：

- `platform carrier` 的 loading/packaging/registration
- `platform FFI crate` 的 proxy source 和 platform runtime state
- native artifact placement

## 后果

- 架构 review 不应建议按平台拆分 Dart request execution pipeline。
- Android、iOS、macOS、Windows 的 request path 应保持同一 `execute_async` contract。
- FFI ABI 变更必须同步 Rust core、所有 platform FFI crate、Dart bindings 和 tests。
- 优化 transport performance 时，应优先深化共享 transport module 或统一 ABI，而不是新增平台专属绕行路径。

## 替代方案

- 按平台提供不同 request pipeline：拒绝。它会让 public/native bridge 泄漏平台执行细节。
- 通过 isolate/JSON/binary fallback 做平台专属执行：拒绝作为当前方向。它降低 locality，并重复 transport semantics。
- 直接把 platform choice 暴露到 public API：拒绝。它违反 ADR-0001。

## 提炼来源

- `docs/superpowers/specs/2026-03-29-unified-async-ffi-transport-design.md`
- `docs/superpowers/specs/2026-03-26-rust-net-ffi-performance-design.md`
- `native/nexa_http_native_core/src/api/ffi.rs`
- `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- `.trellis/spec/nexa_http_native_core/backend/directory-structure.md`
