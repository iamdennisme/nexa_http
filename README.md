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

`Flutter app -> NexaHttpClient -> Call -> internal engine -> worker isolate -> Dart request mapping -> FFI bridge -> platform runtime SPI -> nexa_http_native_core -> HTTP transport`

Current layer responsibilities:

- Public HTTP API layer: `packages/nexa_http/lib/nexa_http.dart`, `packages/nexa_http/lib/src/api/*`
  Exposes stable HTTP concepts only: `NexaHttpClient`, `NexaHttpClientBuilder`, `Request`, `RequestBuilder`, `RequestBody`, `Response`, `ResponseBody`, `Headers`, `MediaType`, `Call`, `Callback`, and `NexaHttpException`.
- Client and call facade layer: `packages/nexa_http/lib/src/nexa_http_client.dart`, `packages/nexa_http/lib/src/client/*`
  Owns the lightweight client shape and per-request `Call` execution model.
- Internal engine layer: `packages/nexa_http/lib/src/internal/engine/*`
  Lazily initializes shared worker/native resources on the first real `execute()` call and reuses pooled native clients.
- Internal worker and FFI bridge layer: `packages/nexa_http/lib/src/worker/*`, `packages/nexa_http/lib/src/data/*`
  Translates public requests into the worker/native transport contract and maps native results back into Dart response objects.
- Platform carrier and SPI layer: `packages/nexa_http_native_*`, `package:nexa_http/nexa_http_platform.dart`
  Registers the per-platform runtime hook and packages the native binary without polluting the root end-user API.
- Native core layer: `native/nexa_http_native_core`
  Owns the shared ABI, runtime contract, transport execution, and native-side platform integration.

This means:

- Dart stays responsible for API shape, call orchestration, and lazy engine startup
- Rust stays responsible for actual transport execution
- all supported platforms share one async FFI request pipeline
- platform differences are handled by carrier packages and native platform modules, not by the public Dart API
- proxy state is owned by each native platform runtime, and `nexa_http_native_core` only rebuilds clients when the platform proxy generation changes

## 3. Usage

### Release consumption

Recommended production usage is to pin all packages to the same git tag:

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http
  nexa_http_native_android:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http_native_android
  nexa_http_native_ios:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
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
```

Production usage should treat `git + tag` as first-class. `path` mode is intended for local debugging and workspace iteration.

### Client usage

The root package now exposes an OkHttp-aligned HTTP API.

`RequestBuilder` supports `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`.

`NexaHttpClient` is lightweight and synchronous. Worker startup, native library loading, and pooled native-client creation happen lazily on the first real `call.execute()`.

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .baseUrl(Uri.parse('https://api.example.com/'))
    .callTimeout(const Duration(seconds: 10))
    .userAgent('nexa_http/1.0.1')
    .build();

final request = RequestBuilder()
    .url(Uri(path: '/healthz'))
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body!.string();
```

Request examples:

```dart
final getResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/healthz')).get().build(),
).execute();

final postResponse = await client.newCall(
  RequestBuilder()
      .url(Uri(path: '/users'))
      .post(
        RequestBody.fromString(
          '{"name":"alice"}',
          contentType: MediaType.parse('application/json; charset=utf-8'),
        ),
      )
      .build(),
).execute();

final putResponse = await client.newCall(
  RequestBuilder()
      .url(Uri(path: '/users/1'))
      .put(
        RequestBody.fromString(
          '{"name":"alice-updated"}',
          contentType: MediaType.parse('application/json; charset=utf-8'),
        ),
      )
      .build(),
).execute();

final deleteResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/users/1')).delete().build(),
).execute();

final patchResponse = await client.newCall(
  RequestBuilder()
      .url(Uri(path: '/users/1'))
      .method(
        'PATCH',
        RequestBody.fromString(
          '{"name":"alice-patched"}',
          contentType: MediaType.parse('application/json; charset=utf-8'),
        ),
      )
      .build(),
).execute();

final headResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/healthz')).head().build(),
).execute();

final optionsResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/users')).method('OPTIONS').build(),
).execute();
```

Platform carrier packages should use `package:nexa_http/nexa_http_platform.dart` for runtime registration. End-user app code should stay on `package:nexa_http/nexa_http.dart`.

### Local verification commands

```bash
dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
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

- `git + ref: v1.0.1`
- local `path`

Observed result:

- real GET requests through `NexaHttpClient` passed in both modes
- external Flutter test suites passed in both modes
- real image download flow through `NexaHttpImageFileService` also passed in both modes

### Image-performance verification

The existing image-performance page was reused unchanged.

Latest Android real-device benchmark (`2026-03-29`, device `V2405A`, LAN server `192.168.1.16:8080`, `24` fixture images):

| Transport | First screen | Avg latency | P95 latency | Throughput | Requests | Failures |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `defaultHttp` | `329 ms` | `92 ms` | `167 ms` | `14.09 MiB/s` | `24` | `0` |
| `rustNet` | `186 ms` | `55 ms` | `86 ms` | `22.03 MiB/s` | `24` | `0` |

Relative result on this run (`rustNet` vs `defaultHttp`):

- first-screen time: `-43.47%`
- average latency: `-40.22%`
- p95 latency: `-48.50%`
- throughput: `+56.42%`

These are local-network measurements on one device, not universal release benchmarks.
