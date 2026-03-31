# nexa_http

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP workspace with an OkHttp-style Dart API on top of
a Rust transport runtime.

## Workspace

The repository is split into a small number of responsibilities:

- `packages/nexa_http`: public Dart package used by Flutter apps
- `packages/nexa_http_native_android|ios|macos|windows`: platform carrier
  packages that register and package the native runtime
- `packages/nexa_http/native/rust_net_native`: Rust transport implementation
- `fixture_server/`: local HTTP fixture server used by the example app and tests
- `scripts/`: workspace build and verification helpers

The public mental model is intentionally narrow:

- apps use HTTP concepts only
- carrier packages hide runtime registration
- transport startup stays lazy and internal

## Public API

The root library is [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart).

It exports:

- `NexaHttpClient`
- `NexaHttpClientBuilder`
- `Request`
- `RequestBuilder`
- `RequestBody`
- `Response`
- `ResponseBody`
- `Headers`
- `MediaType`
- `Call`
- `Callback`
- `NexaHttpException`

Typical usage:

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('example-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/healthz'))
    .header('accept', 'application/json')
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
```

`NexaHttpClient` is lightweight and synchronous. Native loading, worker startup,
and pooled transport acquisition happen lazily on the first real
`call.execute()`.

## Platform Packages

End-user application code should stay on `package:nexa_http/nexa_http.dart`.

Carrier packages use `package:nexa_http/nexa_http_platform.dart` internally to
register the native runtime. That SPI exists for packaging, not for normal app
code.

Example workspace dependency setup:

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

When consuming from Git instead of `path`, pin `nexa_http` and the matching
carrier package to the same ref.

## Example App

The demo app lives in [`packages/nexa_http/example`](./packages/nexa_http/example).

It has two pages:

- `HTTP Playground`: build a request with the public API and inspect the real
  response
- `Benchmark`: compare `nexa_http` against Dart `HttpClient` with concurrent
  `bytes` and `image` scenarios

Run the fixture server:

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

Run the example:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

Default local base URLs:

- macOS / Windows host: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`

The benchmark page exposes a small set of parameters:

- `baseUrl`
- `scenario`: `bytes` or `image`
- `concurrency`
- `totalRequests`
- `payloadSize`
- `warmupRequests`
- `timeout`

## Verification

Workspace commands:

```bash
dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
```

Focused package commands:

```bash
cd packages/nexa_http
fvm dart test

cd packages/nexa_http/example
fvm flutter test
fvm flutter analyze
```
