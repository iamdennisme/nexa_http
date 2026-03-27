# Nexa HTTP Federated Native Design

## Status

Approved in chat on 2026-03-27.

## Context

The current repository has already started splitting Flutter-side native carrier packages, but the native runtime boundary is still centered around a single Rust crate:

- `packages/rust_net/native/rust_net_native`

That means the current structure only partially reflects the intended architecture:

- Flutter carrier packages exist, but they do not own the platform Rust implementations
- The public Dart package still owns native build and artifact resolution responsibilities
- Release and local integration still lean on path-style workspace assumptions

This is not the final direction.

The target design is a breaking redesign around:

1. Inversion of control in Rust
2. Federated Flutter packaging
3. Per-platform Rust implementation crates
4. A pure Dart public API package
5. Explicit platform package composition by consuming apps

The project will also be renamed from `rust_net` to `nexa_http`.

## Goals

- Rename the product and package family to `nexa_http`
- Make `nexa_http` a pure Dart public API package
- Move shared Rust logic into a platform-agnostic core crate
- Move each platform Rust implementation into the matching Flutter platform package
- Keep one uniform C ABI across all platforms
- Use Flutter federated package composition so apps opt into only the platform packages they ship
- Support both published package consumption and local native debugging without forcing `path:` integration
- Keep room for future platform-sensitive features beyond proxy discovery

## Non-Goals

- Preserving package compatibility with the existing `rust_net` names
- Preserving the current single-crate native layout
- Keeping compatibility shims such as `rust_net_core`
- Designing a runtime plugin registry inside Rust
- Making source builds the only supported consumption path
- Solving every future platform feature in V1

## Design Principles

- Repository boundaries should match runtime boundaries
- The public Dart package must not own native artifact production or distribution policy
- The Rust core must not contain `cfg(target_os)` platform logic
- Platform crates should stay thin and only own platform capability injection plus FFI export glue
- Consuming apps should explicitly depend on the platform packages they ship
- Published consumption must be first-class; local path integration is a development mode, not the default model

## Proposed Repository Structure

```text
Cargo.toml

native/
  nexa_http_native_core/
    Cargo.toml
    include/
      nexa_http_native.h
    src/
      lib.rs
      api/
      platform/
      runtime/

packages/
  nexa_http/
    lib/
    test/
    pubspec.yaml
    ffigen.yaml

  nexa_http_native_android/
    pubspec.yaml
    hook/
    lib/
    android/
    native/
      nexa_http_native_android_ffi/
        Cargo.toml
        src/

  nexa_http_native_ios/
    pubspec.yaml
    hook/
    lib/
    ios/
    native/
      nexa_http_native_ios_ffi/
        Cargo.toml
        src/

  nexa_http_native_macos/
    pubspec.yaml
    hook/
    lib/
    macos/
    native/
      nexa_http_native_macos_ffi/
        Cargo.toml
        src/

  nexa_http_native_linux/
    pubspec.yaml
    hook/
    lib/
    linux/
    native/
      nexa_http_native_linux_ffi/
        Cargo.toml
        src/

  nexa_http_native_windows/
    pubspec.yaml
    hook/
    lib/
    windows/
    native/
      nexa_http_native_windows_ffi/
        Cargo.toml
        src/
```

## Responsibility Boundaries

### `packages/nexa_http`

This is the only public Dart API package.

It owns:

- public request, response, exception, and client APIs
- Dio integration
- Dart FFI bindings generated from the shared C header
- dynamic library loading through a registry abstraction
- Dart-side request and response mapping

It does not own:

- Rust source builds
- native artifact download logic
- platform-specific library path lookup
- platform registration implementation

### `native/nexa_http_native_core`

This is the pure Rust core crate.

It owns:

- shared request, response, and error models
- runtime orchestration
- Tokio runtime lifecycle
- client registry and rebuild behavior
- proxy merge, normalization, validation, and runtime application
- platform capability traits and data models
- shared ABI contract definitions

It produces:

- `rlib` only

It does not produce:

- the final native artifacts consumed by Flutter apps

### `packages/nexa_http_native_<platform>`

Each package is a real platform assembly unit, not just an artifact drop location.

Each package owns:

- the Flutter package consumed by apps
- the build hook for that platform package
- Dart-side auto-registration into `nexa_http`
- the platform Rust implementation crate
- delivery of the final native artifact for that platform

### `packages/nexa_http_native_<platform>/native/nexa_http_native_<platform>_ffi`

Each platform Rust crate owns:

- implementation of the platform capability trait
- platform-specific system proxy discovery
- uniform C ABI symbol export wired into the shared runtime

Each platform crate does not own:

- request execution policy
- public Dart API
- ABI divergence from other platforms

## Rust Core Architecture

The Rust core is structured around a shared runtime plus injected platform capabilities.

Suggested layout:

```text
native/nexa_http_native_core/src/
  lib.rs
  api/
    error.rs
    ffi.rs
    request.rs
    response.rs
  platform/
    capabilities.rs
    mod.rs
    proxy.rs
  runtime/
    client_registry.rs
    executor.rs
    tokio_runtime.rs
```

### Platform Capability Trait

The core inversion point is a platform capability provider owned by each platform crate.

Suggested shape:

```rust
pub trait PlatformCapabilities: Send + Sync + 'static {
    fn proxy_settings(&self) -> ProxySettings;
    fn platform_signature(&self) -> PlatformSignature;
}
```

V1 may keep `platform_signature()` derived from the returned proxy settings if that keeps the surface smaller, but the type names should remain platform-oriented rather than proxy-oriented.

The core should avoid naming the boundary `ProxyProvider`, because the architecture is intentionally broader than proxy handling.

### Shared Runtime Container

The core crate should expose a reusable runtime container, parameterized by a platform capability implementation.

Suggested shape:

```rust
pub struct NexaHttpRuntime<P: PlatformCapabilities> {
    capabilities: P,
    clients: Mutex<HashMap<u64, ClientEntry>>,
    next_client_id: AtomicU64,
    tokio: Runtime,
}
```

This runtime owns:

- client creation
- async request dispatch
- client rebuild checks when effective platform settings change
- C ABI result encoding

Each platform crate then only needs:

1. one platform capability implementation
2. one static runtime instance
3. thin exported ABI functions that forward into the shared runtime

### Client Rebuild Semantics

The current rebuild trigger based on effective proxy signature should be generalized and renamed to platform feature signature.

The shared runtime flow is:

1. Read current platform capabilities
2. Merge environment fallback policy where applicable
3. Compute the effective platform signature
4. Rebuild the underlying `reqwest::Client` when that signature changes

The core crate owns this logic. Platform crates only supply current system state.

## Shared C ABI Contract

All platform crates must export the same ABI.

The single source of truth is:

- `native/nexa_http_native_core/include/nexa_http_native.h`

That header defines:

- ABI structs such as `NexaHttpBinaryResult`
- callback signatures
- exported functions such as:
  - `nexa_http_client_create`
  - `nexa_http_client_execute_async`
  - `nexa_http_client_close`
  - `nexa_http_binary_result_free`

Rules:

- Dart bindings are generated once in `packages/nexa_http`
- platform crates may not add private exported functions in V1
- the ABI must stay uniform across all platforms

## Dart FFI Strategy

V1 should continue using `ffigen` plus explicit `DynamicLibrary` loading.

Reasoning:

- native assets are emitted by platform packages, not by the public Dart package
- the public package still needs one stable binding surface
- explicit library loading keeps package boundaries obvious and avoids hidden cross-package native resolution assumptions

The Dart public package should have three internal layers:

```text
packages/nexa_http/lib/src/
  bindings/
  loader/
  data_source/
```

- `bindings/`: generated FFI bindings
- `loader/`: registry-based library acquisition
- `data_source/`: ABI calls plus request and response mapping

## Flutter Federated Packaging Model

`nexa_http` uses federated-style package composition, but the implementation should be shaped around FFI carrier packages rather than MethodChannel-oriented plugin patterns.

### Consumer Dependencies

A consuming app explicitly selects the platform packages it ships:

```yaml
dependencies:
  nexa_http: ^3.0.0
  nexa_http_native_android: ^3.0.0
  nexa_http_native_ios: ^3.0.0
```

Rules:

- `nexa_http` does not depend on any platform package
- consuming apps own the platform package set
- only included platform packages participate in the build graph

### Dart Registration Boundary

The public package exposes a small registry interface.

Suggested shape:

```dart
abstract class NexaHttpNativeRuntime {
  DynamicLibrary open();
}

abstract final class NexaHttpPlatformRegistry {
  static NexaHttpNativeRuntime? instance;
}
```

Each platform package provides a Dart registration class and registers itself through Flutter plugin registration.

The public package then:

- reads `NexaHttpPlatformRegistry.instance`
- opens the library through that interface
- throws a clear configuration error if no platform package registered an implementation

### Platform Package Plugin Metadata

Each platform package should declare itself as a Dart-side plugin implementation for `nexa_http`, using Flutter plugin metadata that supports:

- package registration
- Dart plugin entrypoints
- FFI plugin packaging

The intent is:

- consuming apps add the package explicitly
- Flutter build tooling executes the package's native hook
- plugin registration wires the platform loader into `nexa_http`

`default_package` is not recommended in V1 because the design goal is explicit composition, not implicit endorsement.

## Platform Artifact Model

### Android

- final artifact: `.so`
- build hook compiles `nexa_http_native_android_ffi`
- artifact is bundled into the Android app

### Linux

- final artifact: `.so`
- build hook compiles `nexa_http_native_linux_ffi`

### Windows

- final artifact: `.dll`
- build hook compiles `nexa_http_native_windows_ffi`

### macOS

- final artifact: `.dylib` is acceptable
- build hook compiles `nexa_http_native_macos_ffi`

### iOS

iOS should not continue with the current loose dynamic library approach.

V1 should use an Apple-compatible packaging model such as:

- `staticlib`, or
- another Xcode-linkable Apple packaging form if required by the toolchain

Dart-side loading on iOS should use `DynamicLibrary.process()` rather than relying on a directly opened standalone dylib.

## Build and Packaging Route

The build route for each app should be:

1. the app depends on `nexa_http` plus selected platform packages
2. Flutter resolves only those selected packages
3. each selected platform package runs its build hook
4. the hook resolves the native artifact for that package
5. the artifact is emitted as a code asset and packaged into the app
6. Flutter plugin registration runs the package's Dart registration entrypoint
7. `nexa_http` obtains the platform runtime through the registry and invokes the uniform ABI

## Release and Distribution Strategy

Published consumption must be first-class.

Path-based workspace integration remains supported, but it is not the primary model.

### Primary Consumption Mode: Published Packages Plus Prebuilt Native Artifacts

Default app integration should be:

- `nexa_http` published as a Dart package
- each platform package published as its own Dart package
- each platform package build hook downloads the matching prebuilt native artifact for its package version
- the hook verifies checksums and emits the artifact as a code asset

This mode must not require:

- Rust toolchains on consumer machines
- Cargo knowledge in consumer apps
- path dependencies

### Secondary Consumption Mode: Git Dependencies

Consumers should also be able to depend on:

- `nexa_http` from Git
- selected platform packages from the same repository via Git paths

In that mode, the build hook should still default to prebuilt artifact download based on the package version or release metadata.

That allows external apps to try unpublished commits without switching to `path:` integration.

### Local Development Mode: Workspace Path Dependencies

Path dependencies remain useful for:

- monorepo development
- example apps
- Dart API refactors in lockstep with package changes

This mode stays supported, but documentation should present it as a development workflow, not the standard integration story.

### Native Debug Override Mode

Platform packages should expose hook overrides for local native debugging.

Suggested environment variables:

- `NEXA_HTTP_NATIVE_<PLATFORM>_SOURCE_DIR`
- `NEXA_HTTP_NATIVE_<PLATFORM>_LIB_PATH`
- `NEXA_HTTP_NATIVE_MANIFEST_PATH`
- `NEXA_HTTP_NATIVE_RELEASE_BASE_URL`

That enables advanced workflows such as:

- published Dart packages plus local Rust source builds
- published Dart packages plus a locally built native binary
- private release mirrors
- local manifest testing

This is important because it avoids forcing an entire Flutter app to switch to `path:` dependencies just to debug one native platform layer.

## Artifact Manifest Model

The prebuilt release flow should use a manifest per released version.

The manifest records at least:

- package version
- target platform
- target architecture
- target SDK when relevant
- artifact file name
- download URL or relative path
- SHA-256 digest

Hooks use the manifest to:

- select the correct artifact
- download or copy it
- verify integrity
- emit the final code asset

## Release Pipeline

Recommended release flow:

1. CI builds each platform Rust crate for supported targets
2. CI uploads release artifacts to the chosen artifact store
3. CI generates and publishes the manifest
4. CI publishes:
   - `nexa_http`
   - `nexa_http_native_android`
   - `nexa_http_native_ios`
   - `nexa_http_native_macos`
   - `nexa_http_native_linux`
   - `nexa_http_native_windows`

The versioning model should stay aligned across the family in V1.

## Testing Strategy

### Rust Core Tests

The core crate tests:

- request and response model handling
- error mapping
- runtime orchestration
- client registry lifecycle
- proxy merge and normalization logic
- rebuild behavior when platform signatures change

These tests should stay pure and platform-agnostic.

### Platform Rust Tests

Each platform crate tests:

- mapping from platform-specific raw values to shared capability models
- trait injection into the shared runtime
- minimal ABI smoke behavior where practical

They should not depend on live device or OS state.

### Dart Public Package Tests

`packages/nexa_http` tests:

- public API behavior
- Dio adapter behavior
- registry failure modes when no platform package is registered
- request and response mapping against the ABI layer

### Platform Package Tests

Each Flutter platform package tests:

- Dart registration into `nexa_http`
- build hook behavior
- target-platform filtering for hook execution
- artifact resolution policy

### End-to-End Tests

Keep the fixture server and split end-to-end coverage into:

- Rust-level native runtime tests
- Flutter app integration tests using `nexa_http` plus selected platform packages

Proxy and real HTTP smoke tests should remain anchored in `fixture_server/`.

## Migration Plan

### Phase 1: Rename and Freeze the ABI

- rename the package family to `nexa_http`
- add repo-root `Cargo.toml` as the Rust workspace root
- create `native/nexa_http_native_core`
- move shared runtime and ABI definitions into the core crate
- add `include/nexa_http_native.h`
- repoint `ffigen` in `packages/nexa_http` to the shared header

This phase defines the long-term contract.

### Phase 2: Make the Public Dart Package Pure

- rename `packages/rust_net` to `packages/nexa_http`
- remove native build hooks from the public package
- remove artifact manifest download logic from the public package
- keep only Dart API, bindings, registry, and data mapping

### Phase 3: Prove the Platform Pattern with One Target

Recommended first target:

1. macOS
2. Linux

That first platform should:

- add the platform Rust crate under its Flutter package
- implement `PlatformCapabilities`
- export the uniform ABI
- register itself into the public package
- build and run successfully through the package hook

This phase validates the architecture before copying it to noisier mobile targets.

### Phase 4: Roll Out Remaining Platforms

Recommended order:

1. macOS
2. Linux
3. Windows
4. iOS
5. Android

The order intentionally delays the most toolchain-heavy platforms until the pattern is stable.

### Phase 5: Rebuild Distribution Scripts

- update release scripts to build platform-local Rust crates
- generate manifests from the new artifact locations
- support published, Git, path, and local native override flows

### Phase 6: Delete Legacy Structure

Delete:

- `packages/rust_net/native/rust_net_native`
- the public package's native build hook
- compatibility shim packages such as `rust_net_core`
- old artifact discovery and manifest resolution logic tied to `rust_net`
- old scripts and docs that assume the single-crate layout

## Recommended V1 Decisions

- Adopt the `nexa_http` name immediately
- Keep one pure Rust core crate plus one Rust crate per platform package
- Keep the ABI uniform and generated from one shared header
- Keep the public Dart package pure
- Use explicit platform package dependencies in consuming apps
- Make published package plus prebuilt native artifact download the default distribution model
- Keep local source debugging available through hook overrides rather than requiring path dependencies

## Open Constraints to Respect During Implementation

- iOS packaging must follow Apple-compatible linking rules
- Flutter package metadata must support Dart registration and FFI asset packaging cleanly
- release automation must treat platform artifacts as versioned deliverables, not incidental byproducts
- implementation should avoid reintroducing native artifact policy into the public Dart package

## Why This Design

This design makes the architecture real instead of nominal.

- The Rust core becomes truly platform-agnostic
- The platform packages become true platform implementation units
- The public Dart package becomes a real API package instead of a mixed API and native distribution package
- The release story supports both published consumption and serious local debugging
- Future platform additions can be made by adding one platform package plus one platform Rust crate without rewriting the core
