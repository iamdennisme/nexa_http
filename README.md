# rust_net workspace

[中文文档](./README.zh-CN.md)


### Project Overview

`rust_net` is a Flutter/Dart HTTP SDK workspace that keeps business-facing APIs
in Dart while delegating transport execution to a Rust `reqwest` core.

This repository is designed for:

- shared domain contracts (`rust_net_core`)
- FFI transport implementation (`rust_net`)
- native Rust transport runtime and Release-backed code-asset packaging
- local fixture/proxy tools for integration testing

### Repository Contents

- `packages/rust_net_core`: domain entities, exceptions, and repository contracts
- `packages/rust_net`: Dart FFI package, build hook, and Dio adapter
- `packages/rust_net/native/rust_net_native`: Rust `cdylib` based on `reqwest`
- `fixture_server/`: local HTTP fixture server and proxy smoke-test tooling
- `scripts/`: multi-platform native build scripts

### Package Details

- `packages/rust_net_core`: Pure Dart domain contracts and models (`RustNetRequest`, `RustNetResponse`, `RustNetException`, `HttpExecutor`, etc.).
- `packages/rust_net`: Dart FFI transport implementation backed by Rust `reqwest`, plus `Dio` adapter integration.

### Local development

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

### Build Native Libraries

When Rust native code changes, maintainers still build platform binaries
locally for validation:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
./scripts/build_native_macos.sh release
./scripts/build_native_android.sh release
./scripts/build_native_ios.sh release
./scripts/build_native_linux.sh release
./scripts/build_native_windows.sh release
```

Tag releases publish immutable per-platform binaries and a manifest to GitHub
Release assets. Consumer builds fetch the matching native asset through
`hook/build.dart`; binaries are no longer meant to be committed to the repo.

### Use In Flutter

`pubspec.yaml` for a private git dependency:

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

Use as a Dio adapter:

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

Use the core client directly:

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(baseUrl: Uri.parse('https://api.example.com/')),
);
final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);
await client.close();
```

### Proxy Behavior

- Proxy selection runs in Rust for every request.
- If the proxy snapshot changes, `rust_net` rebuilds the underlying `reqwest::Client`.
- If no proxy is detected, requests go direct.
- Priority is: platform system proxy first, then env fallback.
- Env fallback keys: `HTTP_PROXY`/`http_proxy`, `HTTPS_PROXY`/`https_proxy`, `ALL_PROXY`/`all_proxy`, `NO_PROXY`/`no_proxy`.

Platform proxy sources:

- Android: `getprop` (`http.proxyHost`, `https.proxyHost`, `socksProxyHost`, `*.nonProxyHosts`)
- iOS/macOS: Apple `SystemConfiguration`
- Linux: GNOME `gsettings` with KDE `kreadconfig` fallback
- Windows: `Internet Settings` registry
- Other targets: env fallback only
- Current scope is manual HTTP/HTTPS/SOCKS proxy settings; PAC is not evaluated yet

### Network Test Tooling

All local network test utilities are grouped under `fixture_server/`:

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

To run only Rust crate compile locally:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### Native Asset Distribution

`packages/rust_net` uses `hook/build.dart` plus `code_assets` to bundle the
correct Rust dynamic library for the target OS/architecture. The build hook
resolves native binaries in this order:

1. explicit manifest override via hook user-defines
2. local maintainer fallback from `native/rust_net_native/target/*`
3. migration fallback from legacy packaged artifacts if still present
4. GitHub Release manifest + per-platform asset download

For local maintainer verification, build the host Rust crate first:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### rust_net_core integration

`rust_net_core` remains a separate package under `packages/rust_net_core`. Consumers can reference both packages from this monorepo using git `path` dependencies (as Kino does).
