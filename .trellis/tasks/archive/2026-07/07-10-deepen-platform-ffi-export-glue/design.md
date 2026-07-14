# Deepen platform FFI export glue - Design

## Decision

Define the nine public C ABI wrappers once in a declarative macro exported by `nexa_http_native_core`. Each platform FFI crate keeps its existing static `RUNTIME`, proxy source, and artifact identity, then invokes the macro with the runtime expression and its concrete platform state type.

The macro is paired with three independent guards:

1. compile-time Rust function-pointer signature assertions;
2. C header to generated Dart binding regeneration and symbol-contract checks;
3. concrete ELF, Mach-O, and PE export inspection on the platform runners that build those artifacts.

The macro is source consolidation, not runtime registration or code generation. Core remains an `rlib`; the platform crates remain the `cdylib` producers.

## Architecture And Boundaries

### Shared Rust core

Add a focused FFI-export module under `native/nexa_http_native_core/src/api/`, exposed through a crate-root macro such as `export_nexa_http_ffi!`.

The macro owns:

- all nine `#[unsafe(no_mangle)] pub extern "C"` definitions;
- their exact argument and return types;
- delegation to the supplied platform runtime or existing core ownership/error helpers;
- compile-time assertions that each emitted function coerces to its expected `extern "C" fn` type;
- a private typed runtime accessor that proves the supplied runtime expression is `NexaHttpRuntime<PlatformState>`.

The macro does not own:

- a global runtime registry;
- any `Lazy` or other static initializer;
- Android polling setup;
- Apple SystemConfiguration state;
- Windows registry state;
- artifact lookup, download, caching, or packaging.

All paths emitted by the macro use `$crate` and fully qualified standard-library types. Platform crates should not need to import FFI structs solely to satisfy macro expansion.

### Platform FFI crates

Each platform `src/lib.rs` retains:

- `mod proxy_source` and its existing public test exports;
- the concrete proxy source type;
- the exact current `RUNTIME` static and initializer;
- one named macro invocation, for example:

```rust
nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<MacosProxySource>,
}
```

Android's `with_background_refresh` construction and thread name remain byte-for-byte equivalent in behavior. iOS, macOS, and Windows retain construction-boundary refresh through `ManagedProxyState::new`.

### Public ABI wrapper contract

| Symbol | Rust C signature | Delegation owner |
| --- | --- | --- |
| `nexa_http_client_create` | `extern "C" fn(*const NexaHttpClientConfigArgs) -> u64` | supplied platform runtime |
| `nexa_http_take_last_error_json` | `extern "C" fn() -> *mut c_char` | core FFI error store |
| `nexa_http_string_free` | `extern "C" fn(*mut c_char)` | core FFI string ownership |
| `nexa_http_request_body_alloc` | `extern "C" fn(usize) -> *mut u8` | `NexaHttpRuntime<PlatformState>` ownership helper |
| `nexa_http_request_body_free` | `extern "C" fn(*mut u8, usize)` | `NexaHttpRuntime<PlatformState>` ownership helper |
| `nexa_http_client_execute_async` | `extern "C" fn(u64, u64, *const NexaHttpRequestArgs, NexaHttpExecuteCallback) -> u8` | supplied platform runtime |
| `nexa_http_client_cancel_request` | `extern "C" fn(u64, u64) -> u8` | supplied platform runtime |
| `nexa_http_client_close` | `extern "C" fn(u64)` | supplied platform runtime |
| `nexa_http_binary_result_free` | `extern "C" fn(*mut NexaHttpBinaryResult)` | `NexaHttpRuntime<PlatformState>` ownership helper |

No wrapper changes safety, pointer ownership, callback scheduling, success values, error storage, or free behavior.

## Contract Flow

```text
nexa_http_native.h
  -> ffigen regeneration
  -> nexa_http_bindings_generated.dart
  -> Dart FFI adapter

core export macro + platform-owned RUNTIME
  -> platform crate macro expansion
  -> platform cdylib
  -> native symbol inspection against the same nine-symbol manifest
```

The C header remains the human-readable cross-language ABI declaration. The Rust macro remains the single Rust definition site. Executable checks connect these two intentionally separate sources without introducing build-time source generation.

## ABI Verification

### Source contract

Add a small workspace ABI-contract helper with one ordered list of the nine public symbol names. Focused tests verify:

- C header function declarations expose exactly that public list;
- generated Dart `_lookup` entries expose exactly that list;
- Android's Gradle source-build safety check contains the complete list rather than its current six-symbol subset;
- each of the four platform `lib.rs` files invokes the shared macro once and no longer defines explicit `#[unsafe(no_mangle)]` wrappers.

Signature parity between the C header and Dart is verified by rerunning ffigen and requiring no whitespace-insensitive declaration diff. Rust signature parity is enforced at compile time inside each macro expansion.

### Concrete artifact contract

Extend workspace tooling with a `verify-native-abi` command. It resolves the packaged artifacts produced for the current CI host and invokes an object-format-appropriate symbol tool:

- Android ELF: NDK `llvm-nm` with dynamic, defined symbols;
- Apple Mach-O: `/usr/bin/nm` with global, defined symbols and leading underscore normalization;
- Windows PE: `dumpbin /exports`, with `llvm-readobj --coff-exports` and `llvm-nm` as explicit fallbacks when available.

The parser keeps only normalized names beginning with `nexa_http_`, excludes the pre-existing `nexa_http_test_*` helpers, and requires exact equality with the nine-symbol public manifest. Errors report the artifact path, target tuple, command used, missing symbols, and unexpected symbols.

Parser unit tests use representative ELF/Mach-O/PE command output so formatting changes are caught without requiring every object format on one host.

### CI ownership

| Runner | Built and inspected artifacts |
| --- | --- |
| Ubuntu + Android NDK | Header-to-Dart ffigen semantic-diff guard plus Android arm64-v8a, armeabi-v7a, x86_64 ELF libraries |
| macOS | host macOS dylib plus iOS device and simulator Mach-O libraries |
| Windows | x64 Windows DLL |

The ffigen guard regenerates `nexa_http_bindings_generated.dart` from the canonical header and requires a clean whitespace-insensitive diff. This ignores formatter-only wrapping from the pinned SDK while still rejecting changed declarations; the exact symbol-name test remains whitespace-sensitive. The new artifact verifier runs after the existing native build scripts and before clean-host verification. A runner never silently passes an artifact it could not build or inspect; unsupported local coverage is recorded as runner-owned rather than skipped as success.

## TDD Sequence

1. RED: add the public ABI contract test. It fails against the current Android six-symbol safety list, proving the repository lacks a complete parity guard before wrapper replacement.
2. GREEN: introduce the shared nine-symbol contract helper and complete the Android list.
3. RED: add the structural expectation that each platform uses one shared export invocation and has no local no-mangle wrappers.
4. GREEN: add the core macro and migrate each platform crate without changing its runtime initializer.
5. RED/GREEN: add symbol-output parser fixtures and the concrete artifact verifier, then wire it into each platform CI job.
6. REFACTOR: remove imports made obsolete by macro expansion and keep the macro/API module focused.

Existing Rust ownership tests and Dart finalizer tests remain behavior-level regression coverage.

## Flutter SDK Contract Mapping

- Host dependencies remain `nexa_http` plus the target `nexa_http_native_<platform>` carrier package.
- Host runtime code continues to import only `package:nexa_http/nexa_http.dart`.
- `nexa_http_native_internal`, platform carrier internals, platform FFI crates, and Rust core remain hidden implementation packages.
- Plugin registration, download, checksum verification, caching, source/release selection, and packaging remain owned by the existing carrier hooks and `nexa_http_native_internal`; the macro does not participate in those stages.
- No public configuration, environment variable, Dart define, or native-project edit is introduced.
- Runtime failure reporting is unchanged. The new maintainer/CI verifier reports stage, platform target, artifact path, symbol tool, and exact missing/unexpected symbols.
- `verify-development-path` and `verify-external-consumer` prove that clean hosts still integrate through dependency declarations and the normal Flutter build chain. The existing release-consumer gate remains required for an actual release candidate, but release materialization is not changed by this task.
- No Podfile, Xcode build phase, Gradle consumer file, CMake file, or host source workaround is allowed.

## Compatibility And Rollout

- No C ABI version bump or migration is required.
- The checked-in C header and generated Dart bindings remain unchanged. Regeneration must have zero non-whitespace declaration diff; the pinned formatter currently rewraps two existing declarations.
- Crate names, crate types, target triples, output filenames, carrier paths, and release asset names remain unchanged.
- Existing published binaries are unaffected. Newly built binaries must pass the symbol verifier before CI accepts them.
- The three `nexa_http_test_*` helpers retain their current implementation and visibility, but remain outside the public manifest.

## Tradeoffs

- The macro adds a Rust mechanism with no prior repository precedent. A named invocation, one focused module, compile-time signature assertions, and artifact-level checks keep the indirection auditable.
- Explicit wrappers would be easier to read in each platform file, but would preserve four independently editable ABI copies. The selected design prioritizes drift prevention.
- A procedural macro or build-time generator could derive more artifacts from one schema, but would add a crate/toolchain boundary disproportionate to nine stable wrappers.
- Moving exports directly into the core library would require core-owned platform runtime registration and violate ADR-0004.
- Object symbol tools differ by runner. Keeping thin, tested adapters around standard platform tools is smaller than adding a cross-format binary parser dependency to production crates.

## Rollback

If macro expansion fails on an unavailable target, restore explicit platform wrappers from the pre-change implementation while retaining the new ABI contract tests and artifact verifier. No Dart, carrier, header, runtime-state, or packaging rollback should be necessary because those surfaces do not change.
