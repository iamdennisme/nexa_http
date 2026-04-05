# nexa_http

[中文说明](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP SDK with an OkHttp-style Dart API and a Rust-powered transport core.

The goal of this repository is simple:

- app code talks to one public SDK
- platform-specific native loading stays behind that SDK
- shared transport logic lives in Rust
- platform carriers package the right native binaries for each target

## Why this exists

If you like the ergonomics of building requests in Dart, but you want the transport layer to live in Rust, this project is for you.

`nexa_http` gives you:

- a small public Dart surface
- lazy native startup behind the API
- one shared Rust native core
- platform carriers for Android, iOS, macOS, and Windows

## Install

Application code should depend on:

1. `nexa_http` — required, the public SDK
2. `nexa_http_native_<platform>` — add the carrier packages for the platforms your app supports

### Git dependency

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: vX.Y.Z
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: vX.Y.Z
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

## Architecture

This repository is organized around five layers:

1. `app/demo` — the official demo app
2. `packages/nexa_http` — the public SDK
3. `packages/nexa_http_native_internal` — the internal native runtime/loading layer
4. `packages/nexa_http_native_<platform>` — platform carriers
5. `native/nexa_http_native_core` — shared Rust core

### What external projects actually consume

There are only two kinds of artifacts that matter to consumers:

- `nexa_http`
- the platform carrier packages you choose for your app targets

Everything else is internal implementation detail.

## Demo

The official demo lives in [`app/demo`](./app/demo).

Start the local fixture server from the repository root:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

Then run the demo app:

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

The demo includes:

- `HTTP Playground`
- `Benchmark`

More demo details are in [`app/demo/README.md`](./app/demo/README.md).

## Development

Useful local checks:

```bash
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

## Repository layout

- `app/demo` — demo app
- `packages/nexa_http` — public SDK
- `packages/nexa_http_native_internal` — internal native runtime/loading layer
- `packages/nexa_http_native_android` — Android carrier
- `packages/nexa_http_native_ios` — iOS carrier
- `packages/nexa_http_native_macos` — macOS carrier
- `packages/nexa_http_native_windows` — Windows carrier
- `native/nexa_http_native_core` — shared Rust core
- `fixture_server` — local HTTP fixture server for demo and verification

## For developers

A few practical rules shape this repo:

- `nexa_http` is the only public Dart API surface
- app code should not know about internal runtime details
- native carriers own platform packaging and registration
- shared transport logic belongs in `nexa_http_native_core`

## License

[LICENSE](./LICENSE)
