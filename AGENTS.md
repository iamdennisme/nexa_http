# Repository Guidelines

## Project Structure & Module Organization
This Melos-managed workspace combines one public Dart API package with Rust transport runtime code and platform carrier packages.

- `packages/rust_net/`: public Dart/Flutter package, including requests, responses, exceptions, FFI bridge, Dio adapter, examples, and tests.
- `packages/rust_net_native_android|ios|macos|windows|linux/`: thin carrier packages for platform artifacts and build hooks.
- `packages/rust_net/native/rust_net_native/`: Rust `cdylib` transport built on `reqwest`.
- `fixture_server/`: local HTTP fixture server and proxy smoke-test tooling.
- `scripts/`: platform build scripts such as `build_native_all.sh`.

Do not hand-edit generated files like `*.freezed.dart`, `*.g.dart`, or generated FFI bindings; regenerate them.

## Build, Test, and Development Commands
- `dart pub get && dart run scripts/workspace_tools.dart bootstrap`: install workspace dependencies.
- `dart run scripts/workspace_tools.dart analyze`: run `flutter analyze` or `dart analyze` across packages.
- `dart run scripts/workspace_tools.dart test`: run Dart and Flutter tests across the workspace.
- `cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml`: build the Rust crate only.
- `cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml`: run Rust unit tests.
- `./scripts/build_native_all.sh release`: rebuild native artifacts for supported platforms.
- `cd packages/rust_net && dart run build_runner build --delete-conflicting-outputs`: regenerate Freezed and JSON code for the public Dart API package.
- `cd packages/rust_net && dart run ffigen --config ffigen.yaml`: regenerate Dart FFI bindings.

## Coding Style & Naming Conventions
Dart uses 2-space indentation, `lowerCamelCase` members, `UpperCamelCase` types, and `snake_case.dart` filenames. Follow `package:lints` and package-specific `analysis_options.yaml`. Rust should stay `rustfmt`-clean with `snake_case` functions/modules and `UpperCamelCase` types. Keep FFI and serde field names stable in `snake_case`.

## Testing Guidelines
Dart tests live under `packages/rust_net/test` and use `*_test.dart`. Rust tests are inline with `#[cfg(test)]`, mainly in `src/lib.rs` and related modules. For transport, proxy, or FFI changes, run both `dart run scripts/workspace_tools.dart test` and the Rust test command. Use `fixture_server/` when validating real HTTP or proxy behavior.

## Commit & Pull Request Guidelines
Use Conventional Commit style seen in history, for example `perf(rust_net): remove rinf binary bridge` or `docs(readme): rewrite workspace guide`. PRs should include a short behavior summary, touched packages, linked issues when applicable, and the commands used for verification. If Rust code changes, verify the platform build scripts regenerate outputs under the active carrier package directories such as `packages/rust_net_native_android/android/src/main/jniLibs`, `packages/rust_net_native_ios/ios/Frameworks`, `packages/rust_net_native_linux/linux/Libraries`, `packages/rust_net_native_macos/macos/Libraries`, and `packages/rust_net_native_windows/windows/Libraries`, but do not commit those generated binaries.
