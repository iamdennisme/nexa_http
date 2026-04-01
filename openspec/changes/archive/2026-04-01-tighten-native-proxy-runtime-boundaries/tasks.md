## 1. Shared Proxy Runtime Primitives

- [x] 1.1 Add a shared proxy source abstraction in `native/nexa_http_native_core` that separates platform proxy acquisition from runtime coordination.
- [x] 1.2 Implement managed proxy runtime state in `native/nexa_http_native_core` for snapshot caching, generation tracking, and current runtime view access.
- [x] 1.3 Move shared refresh coordination logic into core runtime modules so background refresh behavior is driven by a shared mechanism instead of per-platform copies.

## 2. Platform Runtime Assembly Refactor

- [x] 2.1 Refactor the Android FFI crate to move proxy acquisition into a dedicated platform source module and assemble the shared managed proxy runtime from `lib.rs`.
- [x] 2.2 Refactor the Windows FFI crate to move proxy acquisition into a dedicated platform source module and assemble the shared managed proxy runtime from `lib.rs`.
- [x] 2.3 Refactor the macOS FFI crate to move proxy acquisition into a dedicated platform source module and assemble the shared managed proxy runtime from `lib.rs`.
- [x] 2.4 Refactor the iOS FFI crate to move proxy acquisition into a dedicated platform source module and assemble the shared managed proxy runtime from `lib.rs`.

## 3. Refresh Policy And Verification

- [x] 3.1 Introduce platform-aware refresh mode handling in shared runtime code and wire each platform source to declare its supported mode and cadence.
- [x] 3.2 Replace Android's current aggressive fixed polling assumption with a bounded platform-defined refresh policy.
- [x] 3.3 Add or update Rust tests that lock shared proxy state behavior, platform source integration, and client rebuild behavior after proxy changes.
- [x] 3.4 Add or update Android-focused tests that verify proxy refresh behavior remains bounded and does not rely on high-frequency subprocess spawning assumptions.
