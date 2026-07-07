# nexa_http

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP SDK with an OkHttp-style Dart API and a Rust-powered transport core.

It is built for apps that want a straightforward Dart request API while keeping the transport layer in native code.

## Why use it

- A small, app-facing Dart API
- Rust-powered transport under the hood
- Explicit platform packages for Android, iOS, macOS, and Windows
- A demo app you can run locally to exercise the full Flutter → FFI → Rust path

## Supported platforms

- Android
- iOS
- macOS
- Windows

## Architecture

The monorepo has two main layers:

- **Flutter SDK layer**: `packages/nexa_http`, `packages/nexa_http_native_internal`, platform carrier packages, build hooks, and verification tooling.
- **Native layer**: the shared Rust core, platform FFI crates, and native build scripts.

Platform carriers, build hooks, release assets, and clean-host verification are mechanisms that connect those two layers. They are not separate app-facing APIs.

## Installation

A normal app imports only `package:nexa_http/nexa_http.dart` in runtime code,
but its `pubspec.yaml` declares both `nexa_http` and the platform package for
each target it ships.

### Git dependency

Use a real published release tag. The example below uses `v1.0.2`.

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http_native_macos
```

### Local path dependency

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

## Quick start

The public entrypoint is [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart).

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('my-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/healthz'))
    .header('accept', 'application/json')
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
```

## Demo

The official demo lives in [`app/demo`](./app/demo).

Start the local fixture server from the repository root:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

For repository development, prepare local debug artifacts before running the
workspace demo:

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_ios.sh debug
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

The demo includes:

- `HTTP Playground`
- `Benchmark`

More run details are in [`app/demo/README.md`](./app/demo/README.md).

## Packages

Flutter SDK layer:

- `packages/nexa_http` — public Dart SDK
- `packages/nexa_http_native_internal` — internal runtime/loading and artifact materialization helper
- `packages/nexa_http_native_android` — Android carrier
- `packages/nexa_http_native_ios` — iOS carrier
- `packages/nexa_http_native_macos` — macOS carrier
- `packages/nexa_http_native_windows` — Windows carrier

Native layer:

- `native/nexa_http_native_core` — shared Rust transport core
- `packages/nexa_http_native_*/native/*_ffi` — platform FFI crates

Release builds publish native download assets on GitHub Releases. Carrier build hooks download and verify those assets, then materialize the platform library inside the carrier/App build layout.

## Development

For maintainers, the most useful local checks are:

```bash
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

A fuller verification guide is in [`docs/verification-playbook.md`](./docs/verification-playbook.md).

## License

[LICENSE](./LICENSE)
