# Deepen platform FFI export glue

## Goal

Reduce the coordination cost and drift risk of the duplicated platform FFI export glue while preserving the exact `uniform C ABI`, each platform's runtime-state ownership, and all existing native artifacts and Flutter host integration behavior.

This continues the remaining speculative candidate from the repository architecture review: concentrate the near-identical `nexa_http_*` exports without moving platform-specific proxy/runtime construction into `nexa_http_native_core`.

## Background

Confirmed repository facts:

- Android, iOS, macOS, and Windows platform FFI `src/lib.rs` files contain 264 lines total and each exports the same nine `#[unsafe(no_mangle)] extern "C"` symbols.
- iOS, macOS, and Windows `lib.rs` are 64 lines each. The iOS/macOS diff changes only the proxy source/runtime type; Android adds eight lines for polling runtime construction.
- The repeated wrapper bodies delegate to `NexaHttpRuntime` or shared core FFI ownership helpers. Platform-specific behavior is concentrated in the `RUNTIME` initializer and proxy source type.
- `native/nexa_http_native_core/include/nexa_http_native.h` and `packages/nexa_http/lib/nexa_http_bindings_generated.dart` describe the same nine-symbol ABI consumed by Dart.
- ADR-0003 requires one unified async FFI transport and exact cross-platform ABI consistency. ADR-0004 requires platform FFI crates to keep ownership of proxy/runtime state sources.
- The repository currently has no Rust `macro_rules!` or `#[macro_export]` precedent in native crates, so a macro would be a new local mechanism rather than an established convention.
- The selected maintenance strategy is a declarative macro exported by `nexa_http_native_core`: core owns the nine wrapper definitions and signatures once, while each platform crate supplies its existing runtime state through a local macro invocation.
- Core also exports three `nexa_http_test_*` ownership-test helpers that are linked into production artifacts and used by Dart finalizer tests. They are not declared by the public C header and are not part of the canonical nine-symbol public ABI.

## Requirements

- R1: Preserve the exact symbol names, `extern "C"` signatures, return values, callback contract, pointer ownership, allocation/free pairing, and last-error behavior for all nine `nexa_http_*` exports.
- R2: Keep Android/iOS/macOS/Windows FFI crates as the producers of their existing `cdylib`/`rlib` artifacts and the owners of platform `RUNTIME` construction and proxy/runtime state sources.
- R3: Keep `nexa_http_native_core` platform-independent. Do not move Android polling, Apple SystemConfiguration, Windows registry, or target-specific `cfg` branches into core.
- R4: Do not change the C header, Dart generated bindings, public Dart API, dynamic-library names, target matrix, build hooks, release asset names, or host dependency declarations.
- R5: Centralize all nine wrapper definitions and signatures in one declarative macro exported by `nexa_http_native_core`. Pair the macro with compile-time signature checks and executable symbol/header/binding consistency checks so the ABI remains locally auditable despite the indirection.
- R6: Follow TDD. The first RED must prove a missing ABI parity/contract guard before replacing explicit wrappers.
- R7: Verify all four platform crates, the complete Rust workspace, the concrete non-test `nexa_http_*` export set for artifacts buildable on each platform runner, platform build-hook contracts, and Flutter clean-host integration.
- R8: Scope is limited to FFI export glue and its executable ABI contract. Do not change request execution semantics, proxy parsing/refresh behavior, error schema, or artifact packaging behavior.

## Acceptance Criteria

- [x] AC1: One core-exported declarative macro owns all nine wrapper definitions and signatures; each platform crate retains only platform runtime construction plus the minimum local invocation/wiring required by the macro.
- [x] AC2: Android polling and iOS/macOS/Windows construction-boundary/static runtime initialization behavior remains unchanged.
- [x] AC3: Each platform crate still exposes the same nine C ABI symbols with signatures matching the canonical header and Dart bindings.
- [x] AC4: Allocation/free and binary-result ownership behavior remains covered by executable tests.
- [x] AC5: `cargo fmt --all --check` and `cargo test --workspace` pass.
- [x] AC6: Focused tests for all four platform FFI crates pass.
- [x] AC7: After excluding the existing `nexa_http_test_*` helpers, each inspected native artifact's `nexa_http_*` exports equal the canonical nine-symbol public manifest; Android, Apple, and Windows artifacts are assigned to their respective CI runners.
- [x] AC8: Platform build-hook tests, `verify-development-path`, and `verify-external-consumer` pass without host native-project changes or internal package imports.
- [x] AC9: No public Dart API, C header, generated binding, carrier hook, target matrix, artifact filename, proxy source, Android property, Apple SystemConfiguration, or Windows registry behavior is changed.

## Out Of Scope

- New C ABI functions or ABI versioning.
- Public SDK or Dart binding changes.
- Proxy source/parser changes.
- Runtime execution, callback scheduling, cancellation, or error payload changes.
- Carrier/build-hook/release packaging redesign.
- Removal, renaming, or public-contract promotion of the existing production-visible `nexa_http_test_*` ownership-test symbols. They remain outside the canonical nine-symbol public ABI manifest.
