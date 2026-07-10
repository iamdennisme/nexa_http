# Deepen Apple proxy settings parser

## Goal

Deepen the Apple `proxy settings` parser so iOS and macOS platform FFI crates share one parser implementation while each crate continues to own its platform `proxy source` adapter.

This continues the architecture review candidate "Deepen the Apple proxy settings parser" from `/var/folders/cd/sw2110553dq651kvkmh937jw0000gn/T/architecture-review-20260707-005309.html`.

## Background

Confirmed repository facts:

- ADR-0004 says `platform FFI crate` owns proxy/runtime state sources, and `Rust transport core` must not read OS-specific proxy sources.
- The macOS and iOS `proxy_source.rs` files are 263 lines each and differ only in the source type name and target `cfg`. Both map Apple SystemConfiguration values into `ProxySettings` with identical URL normalization, quoted-value cleanup, bypass deduplication, and `<local>` handling.
- Existing tests duplicate the parser rules in:
  - `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/tests/proxy_settings.rs`
  - `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/tests/proxy_settings.rs`
- Both platform specs require proxy changes to update `tests/proxy_settings.rs` and keep C ABI exports unchanged.
- Workspace and release builds compile the platform FFI manifests from the repository root and package the existing platform dynamic libraries. A pure Rust path dependency can therefore be statically linked without changing carrier packages, artifact names, target-matrix entries, or release download behavior.

## Requirements

- R1: Preserve ADR-0004. iOS/macOS FFI crates must continue to own SystemConfiguration reads and platform proxy source adapters.
- R2: Move pure Apple proxy parsing into one shared native-layer internal crate used by both iOS and macOS adapters.
- R3: Do not move Apple SystemConfiguration/CoreFoundation calls into `native/nexa_http_native_core`.
- R4: Preserve current parser behavior:
  - disabled proxy entries map to `None`
  - HTTP/HTTPS hosts default to `http://`
  - SOCKS host defaults to `socks5://`
  - invalid proxy URLs are ignored
  - quoted/blank values are cleaned
  - bypass entries are cleaned, lowercased, deduplicated, and sorted
  - `exclude_simple_hostnames` adds `<local>`
- R5: Keep public C ABI exports unchanged for iOS and macOS.
- R6: Follow TDD with one vertical slice at a time. First RED should prove the shared Apple parser contract before refactoring platform adapters.
- R7: Scope is limited to Apple proxy parser sharing. Do not change request execution, native artifact packaging, Dart carrier hooks, target matrix, or platform proxy behavior for Android/Windows.
- R8: Preserve the Flutter SDK host integration contract. Host dependency declarations, the `package:nexa_http/nexa_http.dart` runtime import, plugin registration, artifact preparation, and native library names must remain unchanged; the shared parser crate remains an internal native-layer dependency statically linked into the existing iOS/macOS libraries.
- R9: Validate the unchanged host integration through the repository's development-path and external-consumer checks on the current macOS host.

## Acceptance Criteria

- [x] AC1: A shared Apple proxy parser crate exists and has parser-level tests for the shared rules.
- [x] AC2: macOS `MacosProxySource` delegates to the shared parser while keeping SystemConfiguration reads in the macOS FFI crate.
- [x] AC3: iOS `IosProxySource` delegates to the shared parser while keeping SystemConfiguration reads in the iOS FFI crate.
- [x] AC4: Existing iOS/macOS proxy source tests continue to pass, with duplicated parser-rule assertions reduced or moved to shared parser tests.
- [x] AC5: `cargo test -p nexa_http_native_macos_ffi` and `cargo test -p nexa_http_native_ios_ffi` pass.
- [x] AC6: `cargo fmt --all --check` and `cargo test --workspace` pass.
- [x] AC7: No Dart carrier hook, artifact materialization, target matrix, release workflow, C ABI export, Android FFI, or Windows FFI files are modified.
- [x] AC8: TDD evidence is recorded in `implement.md` before completion.
- [x] AC9: `verify-development-path` and `verify-external-consumer` pass on the current macOS host, proving that a host still needs only package dependencies, the public `nexa_http` import, and the standard Flutter build path.

## Out Of Scope

- Android or Windows proxy parser changes.
- Public C ABI changes.
- Dart SDK, Flutter carrier package, build hook, release asset, or clean-host consumer changes.
- Moving platform SystemConfiguration access into `native_core`.
- New proxy behavior beyond preserving current Apple parser semantics.
