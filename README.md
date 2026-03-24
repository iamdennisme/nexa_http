# rust_net workspace

[中文文档](./README.zh-CN.md)

## Overview

`rust_net` is a multi-package Flutter/Dart workspace for HTTP transport backed
by a Rust `reqwest` core. Public request/response APIs stay in Dart, native
library delivery is handled by `hook/build.dart` + `code_assets`, and the
request execute path keeps an internal RINF-style async channel between Dart
and Rust.

This repository contains:

- `packages/rust_net_core`: pure Dart domain contracts and models
- `packages/rust_net`: the transport package, build hook, and Dio adapter
- `packages/rust_net/native/rust_net_native`: the Rust `cdylib`
- `fixture_server/`: local fixture and proxy test tooling
- `scripts/`: native build and release helper scripts

## Package Roles

### `rust_net_core`

Use this package when you want the shared request/response types without
bringing in the Rust transport runtime. It defines `RustNetRequest`,
`RustNetResponse`, `RustNetException`, and `HttpExecutor`.

### `rust_net`

Use this package when you want the Rust-backed transport itself. It exposes:

- `RustNetClient`
- `RustNetDioAdapter`
- the native asset build hook used during application builds

Detailed package-level usage lives in
[`packages/rust_net/README.md`](./packages/rust_net/README.md).

## Install From Git

If your app only imports `package:rust_net/...`, declare `rust_net`. Add
`rust_net_core` only when your app imports it directly.

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net
  rust_net_core:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net_core
```

## Release Model

Releases are tag-driven.

1. A maintainer pushes a tag such as `v2.0.0`.
2. GitHub Actions builds the configured platform binaries.
3. The workflow publishes those binaries, a manifest, and `SHA256SUMS` to the
   GitHub Release.
4. Consumer builds run `packages/rust_net/hook/build.dart`, which resolves the
   correct native asset for the target OS and architecture.

Current build-hook resolution order:

1. explicit manifest override via hook user-defines
2. local maintainer fallback from `native/rust_net_native/target/*`
3. migration fallback from legacy packaged artifacts if they still exist in a
   checkout
4. GitHub Release manifest plus per-platform asset download

Prebuilt native binaries are no longer intended to be committed to the repo.

## Local Development

The repository is pinned to `Flutter 3.41.5` / `Dart 3.11.3` through
`.fvmrc`.

Workspace checks:

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

Maintain the Rust crate locally:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

Platform-specific validation helpers remain under `scripts/`:

```bash
./scripts/build_native_macos.sh release
./scripts/build_native_android.sh release
./scripts/build_native_ios.sh release
./scripts/build_native_linux.sh release
./scripts/build_native_windows.sh release
```

## Test Tooling

Local network fixtures live under `fixture_server/`:

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

Use the fixture server when validating request methods, redirects, timeouts, or
proxy behavior end to end.
