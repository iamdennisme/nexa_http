# Platform Features V1 Design

## Status

Drafted on 2026-03-27.

## Context

The current proxy implementation lives in a single Rust file:

- `packages/rust_net/native/rust_net_native/src/proxy_strategy.rs`

That file currently mixes three concerns:

1. Platform-specific system proxy discovery
2. Proxy env fallback and normalization
3. Runtime proxy application into `reqwest::ClientBuilder`

This boundary is workable while proxy is the only platform-sensitive network feature, but it does not scale well. The next design should not make `proxy` the top-level organizing concept, because proxy is only the first system-level network feature under discussion.

## Goals

- Keep a single Rust crate and a single native runtime artifact
- Make platform-specific code obvious in the directory structure
- Keep `proxy` out of the top-level directory boundary
- Define one unified platform-facing model that runtime code can consume
- Leave room for future system-level network features without another structural rewrite

## Non-Goals

- Splitting the native runtime into multiple Rust crates
- Moving Rust source ownership into Flutter carrier packages
- Designing a plugin-style or independently swappable proxy subsystem
- Changing current proxy behavior as part of this refactor

## Proposed Structure

```text
src/
  lib.rs
  platform.rs
  platform/
    android.rs
    ios.rs
    macos.rs
    windows.rs
    linux.rs
  proxy_strategy.rs
```

## Responsibilities

### `lib.rs`

- Owns runtime orchestration
- Creates and rebuilds `reqwest::Client`
- Reads current platform features before client creation and request execution
- Compares signatures to decide whether client rebuild is needed

`lib.rs` should not know how Android, Apple, Windows, or Linux discover system settings.

### `platform.rs`

- Defines the unified platform model
- Exposes the single entrypoint for reading current platform features
- Uses `cfg(target_os)` to dispatch to `platform/*.rs`
- Owns small pure-data helpers such as signatures

This file intentionally combines "contract + dispatch" in V1 to avoid premature layering.

### `platform/*.rs`

- Read system-level platform settings
- Convert platform-specific state into the unified platform model
- Avoid `reqwest` integration logic
- Avoid env fallback logic

Each platform file should expose a narrow internal entrypoint, for example:

```rust
pub(crate) fn current() -> PlatformFeatures
```

### `proxy_strategy.rs`

- Consumes unified platform features
- Applies env fallback for proxy settings
- Normalizes and validates proxy values
- Implements bypass matching
- Applies effective proxy settings to `reqwest::ClientBuilder`

After the refactor, `proxy_strategy.rs` should no longer contain `target_os` platform discovery branches.

## Unified Model

V1 keeps the model intentionally small:

```rust
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct PlatformFeatures {
    pub(crate) proxy: ProxySettings,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct ProxySettings {
    pub(crate) http: Option<String>,
    pub(crate) https: Option<String>,
    pub(crate) all: Option<String>,
    pub(crate) bypass: Vec<String>,
}
```

Supporting helpers should also live in `platform.rs`:

- `PlatformFeatures::signature() -> String`
- `ProxySettings::is_empty() -> bool`
- `current_platform_features() -> PlatformFeatures`

The top-level type is intentionally named `PlatformFeatures`, not `ProxySnapshot`, because the directory boundary should remain valid if more platform-sensitive network features are added later.

## Data Flow

### Client Creation

1. Read `PlatformFeatures` from `platform::current_platform_features()`
2. Pass features through proxy env fallback in `proxy_strategy`
3. Build `reqwest::Client` from the effective feature set
4. Persist the resulting feature signature on the client entry

### Request Execution

1. Read current `PlatformFeatures`
2. Apply proxy env fallback
3. Compare the effective feature signature with the cached signature
4. Rebuild `reqwest::Client` only when the signature changed

## Runtime Naming Changes

Rename the cached signature field in `ClientEntry`:

- from `proxy_signature`
- to `platform_features_signature`

This keeps the runtime naming aligned with the new boundary. The rebuild trigger is no longer conceptually "proxy changed"; it is "platform features changed".

## Platform-Specific Notes

### Android

- Move existing `getprop`-based proxy discovery out of `proxy_strategy.rs`
- Keep Android-specific refresh caching if still needed after extraction

### iOS and macOS

- Move Apple `SystemConfiguration` lookup into `platform/ios.rs` and `platform/macos.rs`
- V1 may allow some duplicated wrapper logic if that keeps file responsibilities obvious

### Windows

- Move registry-backed `Internet Settings` discovery into `platform/windows.rs`

### Linux

- Include `platform/linux.rs` for structural completeness
- V1 may return `PlatformFeatures::default()` until Linux system proxy discovery is intentionally implemented

## Error Handling

Platform discovery is best-effort in V1:

- `current_platform_features()` should always return `PlatformFeatures`
- Missing, malformed, or unsupported system values should degrade to empty values
- Final proxy validation still happens before applying settings to `reqwest`

This keeps platform discovery resilient while preserving runtime correctness checks.

## Env Fallback Boundary

Environment-variable fallback is not treated as a platform implementation.

It remains in `proxy_strategy.rs` because it is a runtime-level merge policy, not an OS-specific discovery source. V1 keeps the current priority:

1. System platform settings first
2. Env fallback second

## Migration Plan

1. Add `platform.rs` and `platform/*.rs`
2. Move Android, Apple, and Windows system proxy discovery into platform files
3. Update `lib.rs` to consume `PlatformFeatures`
4. Rename `proxy_signature` to `platform_features_signature`
5. Remove platform discovery branches from `proxy_strategy.rs`
6. Keep proxy normalization, bypass, validation, and env fallback in `proxy_strategy.rs`
7. Update tests to reflect the new boundaries

## Testing Strategy

### `platform/*.rs`

- Test parsing and mapping from platform-specific inputs into `PlatformFeatures`
- Avoid tests that depend on live system state

### `proxy_strategy.rs`

- Keep pure-logic tests for:
  - env fallback merging
  - proxy normalization
  - bypass matching
  - per-URL proxy selection

### `lib.rs`

- Keep the rebuild-on-signature-change coverage
- Update assertions to use `platform_features_signature`

## Why This Version

This version is intentionally conservative.

- It keeps one crate
- It keeps one runtime artifact
- It does not introduce trait-heavy indirection
- It makes platform boundaries visible in the tree
- It avoids letting `proxy` dominate the top-level module structure

The design goal is to fix responsibility boundaries first, without turning this refactor into a larger architecture rewrite.
