# ADR-0004: platform-owned proxy runtime state

## 状态

Accepted

## 背景

系统 proxy settings 是平台相关能力。Android 从 properties 读取，Apple 平台从 SystemConfiguration 读取，Windows 从 registry 读取。`Rust transport core` 应专注 HTTP runtime、FFI data structures、shared proxy matching 和 request execution，不应读取 OS-specific configuration。

历史设计文档 `docs/superpowers/specs/2026-03-29-proxy-runtime-state-design.md` 记录了 proxy/runtime state 的方向：平台 runtime 拥有 proxy discovery、snapshot、generation 和 refresh policy；core 只消费抽象 state。

当前 Trellis specs 也规定 platform FFI crate 的 `src/proxy_source.rs` 实现平台 proxy source，core `platform/` 只定义跨平台抽象和 shared proxy matching logic。

## 决策

`platform FFI crate` owns proxy/runtime state sources：

- Android FFI crate owns Android proxy source。
- iOS FFI crate owns iOS proxy source。
- macOS FFI crate owns macOS proxy source。
- Windows FFI crate owns Windows proxy source。

`Rust transport core` consumes abstract platform state through traits and shared models，例如 `ProxyConfigSource`、`RefreshMode`、`PlatformRuntimeState`、`ProxySettings`。

`Rust transport core` 不读取 OS registry、CoreFoundation/SystemConfiguration、Android properties、workspace paths、pub-cache 或 artifact paths。

## 后果

- 架构 review 不应建议把 OS-specific proxy discovery 移回 core。
- 新平台或新 platform-sensitive network feature 应优先在 platform FFI crate 中提供 source/adapter，再通过 core abstraction 消费。
- Core 可以拥有 shared proxy normalization、env fallback、bypass matching 和 reqwest application，但不拥有 OS discovery。
- Platform FFI crate 可以保持 thin adapter：proxy source + runtime wiring + C ABI export。

## 替代方案

- 在 core 中使用 `cfg(target_os)` 读取所有平台 proxy settings：拒绝。它违反 package/runtime 责任边界。
- 在 Dart 层读取平台 proxy settings：拒绝作为当前方向。它会把 platform capability 放到 public/native bridge 上方。
- 为 proxy 建独立 cross-platform plugin system：不作为当前方向。当前 seam 是 platform FFI crate 到 Rust core 的 abstract state。

## 提炼来源

- `docs/superpowers/specs/2026-03-29-proxy-runtime-state-design.md`
- `docs/superpowers/specs/2026-03-27-platform-features-design.md`
- `native/nexa_http_native_core/src/platform/source.rs`
- `native/nexa_http_native_core/src/runtime/managed_proxy_state.rs`
- `.trellis/spec/nexa_http_native_core/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_android_ffi/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_ios_ffi/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_macos_ffi/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_windows_ffi/backend/directory-structure.md`
