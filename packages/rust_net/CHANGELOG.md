## 2.0.0

- Migrate native library distribution to `hook/build.dart` + `code_assets`.
- Bind Rust entrypoints through `@Native` and remove manual dynamic-library path resolution.
- Keep the RINF-style runtime execute channel for asynchronous request execution.
- Remove committed multi-platform native binaries from the package repository.
- Raise the minimum toolchain to Dart 3.11 / Flutter 3.41.5.

## 1.0.0

- Migrate native request execution path to a rinf-style runtime signal channel.
- Enforce Rust-native transport as the primary path for Dio and image cache integrations.
- Shrink Android native artifacts by building release binaries and stripping unneeded symbols.
- Refresh all platform native release artifacts (Android/iOS/macOS/Linux/Windows).

## 0.1.1

- Add Rust-side proxy strategy support with dynamic refresh for HTTP, HTTPS, and SOCKS.
- Refresh package docs and simplify the example app into a request/response test page.
- Add Android project files for the example app.

## 0.1.0

- Split domain contracts into a standalone `rust_net_core` package.
- Keep Flutter FFI transport and Dio integration in `rust_net`.
- Convert repository to a multi-package workspace (`packages/*`).

## 0.0.1

* TODO: Describe initial release.
