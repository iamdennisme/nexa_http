## Why

The Rust native transport layer has package-level separation between the shared core crate and the per-platform FFI crates, but proxy refresh coordination is still implemented independently in each platform crate. That duplication is already causing drift in behavior and unreasonable runtime cost on Android, where proxy refresh relies on frequent polling plus repeated subprocess creation.

## What Changes

- Introduce a shared Rust runtime primitive that owns proxy snapshot caching, generation tracking, and refresh coordination for native clients.
- Keep platform-specific proxy acquisition inside each FFI crate behind an explicit source interface rather than duplicating runtime state management in each platform entrypoint.
- Make proxy refresh policy platform-aware so each platform can declare whether proxy state is static, polled, or otherwise externally refreshed.
- Reduce unnecessary background refresh cost, especially on Android, by replacing the current fixed high-frequency polling assumption with a platform-provided refresh policy.
- Clarify the Rust internal boundary so FFI crates assemble runtime components and platform sources, while `nexa_http_native_core` owns concurrency and client rebuild reactions.

## Capabilities

### New Capabilities
- `native-proxy-runtime-boundaries`: Define how the Rust native runtime separates shared proxy refresh coordination from platform-specific proxy state acquisition.

### Modified Capabilities

- None.

## Impact

- Affected code: `native/nexa_http_native_core`, `packages/nexa_http_native_android/native/nexa_http_native_android_ffi`, `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi`, `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi`, and `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi`.
- Affected systems: Rust native HTTP runtime, platform proxy detection, client rebuild logic, and background refresh behavior.
- Dependencies: no new product dependency is required, but shared Rust runtime abstractions and platform-specific source modules will need new tests to preserve current proxy behavior while changing internal ownership.
