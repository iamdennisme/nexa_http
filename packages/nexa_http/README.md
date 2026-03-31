# nexa_http

`nexa_http` is the public Dart package in the `nexa_http` workspace.

## 1. Package Overview

This package is the Flutter-facing entry point of the project.

It provides:

- `NexaHttpClient`
- `NexaHttpClientBuilder`
- `Request` / `RequestBuilder`
- `RequestBody`
- `Response` / `ResponseBody`
- `Headers` / `MediaType`
- `Call`, `Callback`, and `NexaHttpException`
- image file service support

This package does not own platform packaging by itself. Native loading is completed through the matching platform carrier package:

- `nexa_http_native_android`
- `nexa_http_native_ios`
- `nexa_http_native_macos`
- `nexa_http_native_windows`

## 2. Implementation Logic

Inside the workspace, this package sits at the public API layer.

Its responsibility is:

- expose the Dart API used by Flutter apps
- map Dart-side requests into the native transport contract
- call the registered native runtime through FFI

The execution path is:

`NexaHttpClient -> Call -> internal engine -> worker isolate -> request mapping -> FFI bridge -> registered runtime SPI -> nexa_http_native_core`

This means the package is responsible for API shape, call orchestration, and lazy startup. Actual transport execution remains in the native runtime. All supported platforms use the same async FFI request pipeline.

## 3. Usage

### Release consumption

Recommended production usage is to pin `nexa_http` and the matching platform package to the same git tag:

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http_native_macos
```

### Local workspace consumption

For local development, you can use `path` dependencies:

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

Production usage should prefer `git + tag`. `path` mode is intended for local debugging.

### Client usage

The public package now exposes an OkHttp-aligned API.

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

### Startup note

`NexaHttpClient()` is lightweight and synchronous. Worker startup, native
library loading, and pooled native-client creation happen lazily on the first
real `call.execute()`.

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

Carrier packages should use `package:nexa_http/nexa_http_platform.dart` for runtime registration. End-user code should stay on `package:nexa_http/nexa_http.dart`.

### Local verification

```bash
cd packages/nexa_http
fvm dart test
```

If you need the native binary locally, build the platform artifact first. On macOS the typical flow is:

```bash
./scripts/build_native_macos.sh debug
cd packages/nexa_http
fvm dart test
```

## 4. Test Data

Verified on `2026-03-29` as part of the workspace release-consumption validation.

Observed package-level result:

- the package worked in external `git + ref: v1.0.1` consumption
- the package also worked in local `path` consumption
- real GET requests through `NexaHttpClient` passed against the fixture server
- real image downloads through the image file service passed

Image benchmark data was captured at the workspace level and is recorded in the root [README](../../README.md).
