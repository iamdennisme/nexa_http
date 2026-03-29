# nexa_http

[中文](./README.zh-CN.md)

## 1. Project Overview

`nexa_http` is a Flutter HTTP SDK workspace built around a Dart public API and a Rust transport runtime.

The current project contains these parts:

- `packages/nexa_http`: the public Dart package used by Flutter apps
- `packages/nexa_http_native_android|ios|macos|windows`: platform carrier packages
- `native/nexa_http_native_core`: shared Rust core runtime and ABI contract
- `fixture_server/`: local fixture server for real HTTP and image verification
- `scripts/`: workspace, build, distribution, and release helper scripts

The design target is simple:

- Flutter apps use a stable Dart API
- platform packaging happens in platform carrier packages
- transport execution and platform-specific native behavior stay in Rust

## 2. Implementation Logic

The end-to-end call path is:

`Flutter app -> NexaHttpClient -> Dart request mapping -> FFI bridge -> native platform runtime -> nexa_http_native_core -> HTTP transport`

Current layer responsibilities:

- Public API layer: `packages/nexa_http`
  Exposes `NexaHttpClient`, request/response models, config, exceptions, and image file service.
- Platform carrier layer: `packages/nexa_http_native_*`
  Registers the native runtime for each platform and delivers the packaged native binary.
- Native core layer: `native/nexa_http_native_core`
  Owns the shared ABI, runtime contract, transport execution, and native-side platform integration.

This means:

- Dart stays responsible for API shape and call orchestration
- Rust stays responsible for actual transport execution
- platform differences are handled by native platform modules, not by the public Dart API
- proxy state is owned by each native platform runtime, and `nexa_http_native_core` only rebuilds clients when the platform proxy generation changes

## 3. Usage

### Release consumption

Recommended production usage is to pin all packages to the same git tag:

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http
  nexa_http_native_android:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http_native_android
  nexa_http_native_ios:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http_native_ios
```

Use only the platform carrier packages you actually ship. Desktop targets use the matching `nexa_http_native_<platform>` package in the same way.

### Local workspace consumption

For local development, you can consume the workspace through `path` dependencies:

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos

dependency_overrides:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
```

At the moment, local `path` consumption still needs the `dependency_overrides` entry for `nexa_http`.

### Client usage

`NexaHttpRequest` currently provides four request helpers: `get`, `post`, `put`, and `delete`.

```dart
import 'dart:convert';

import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClient(
  config: NexaHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com/'),
    timeout: const Duration(seconds: 10),
  ),
);

final response = await client.execute(
  NexaHttpRequest.get(uri: Uri(path: '/healthz')),
);

await client.close();
```

Request examples:

```dart
final getResponse = await client.execute(
  NexaHttpRequest.get(
    uri: Uri(path: '/healthz'),
  ),
);

final postResponse = await client.execute(
  NexaHttpRequest.post(
    uri: Uri(path: '/users'),
    headers: {'content-type': 'application/json'},
    bodyBytes: utf8.encode('{"name":"alice"}'),
  ),
);

final putResponse = await client.execute(
  NexaHttpRequest.put(
    uri: Uri(path: '/users/1'),
    headers: {'content-type': 'application/json'},
    bodyBytes: utf8.encode('{"name":"alice-updated"}'),
  ),
);

final deleteResponse = await client.execute(
  NexaHttpRequest.delete(
    uri: Uri(path: '/users/1'),
  ),
);
```

### Local verification commands

```bash
dart pub get
dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
cd packages/nexa_http && fvm dart test
cd packages/nexa_http/example && fvm flutter test
cargo test --workspace
```

For real HTTP verification:

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

Desktop apps use `http://127.0.0.1:8080`. Android emulators use `http://10.0.2.2:8080`.

## 4. Test Data

Verified on `2026-03-29`.

### Interface verification

The HTTP demo was verified against the local fixture server with two external consumption modes:

- `git + ref: v1.0.0`
- local `path`

Observed result:

- real GET requests through `NexaHttpClient` passed in both modes
- external Flutter test suites passed in both modes
- real image download flow through `NexaHttpImageFileService` also passed in both modes

### Image-performance verification

The existing image-performance page was reused unchanged. The benchmark was captured from an external `git` sample on macOS debug mode with `24` fixture images.

| Transport | First screen | Avg latency | P95 latency | Throughput | Requests | Failures |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `defaultHttp` | `802 ms` | `39 ms` | `61 ms` | `35.58 MiB/s` | `24` | `0` |
| `rustNet` | `313 ms` | `9 ms` | `22 ms` | `75.40 MiB/s` | `24` | `0` |

Benchmark command template:

```bash
cd /path/to/your/external_git_sample
env PUB_HOSTED_URL=https://pub.dev \
  FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
  fvm flutter run -d macos \
  --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_SCENARIO=image \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_TRANSPORT=nexa_http \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_IMAGE_COUNT=24
```

These numbers are local debug measurements, not release-build benchmarks.
