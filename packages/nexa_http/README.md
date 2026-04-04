# nexa_http

`nexa_http` is the public Dart package in this workspace.

## What It Exposes

The package keeps the end-user surface small and HTTP-focused:

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

The root entrypoint is `package:nexa_http/nexa_http.dart`.

## What It Does Not Expose

Normal app code should not deal with:

- internal native-layer registration
- worker lifecycle
- native-library loading
- manual startup or shutdown APIs

Apps should continue to import only `package:nexa_http/nexa_http.dart` for the public Dart API. Platform carrier packages are public dependency artifacts that apps declare explicitly per supported target, but they are not primary app-facing API packages.

## Usage

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('example-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/users'))
    .header('accept', 'application/json')
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
```

Supported builder verbs:

- `get()`
- `post(RequestBody)`
- `put(RequestBody)`
- `patch(RequestBody)`
- `delete([RequestBody])`
- `head()`
- `method('OPTIONS')`

`NexaHttpClient` is lightweight and synchronous. Transport startup is internal
and lazy on the first `call.execute()`.

## Platform Integration

`nexa_http` remains the only public Dart API package apps should import. For dependency declaration, apps must add `nexa_http` plus the `nexa_http_native_<platform>` packages for every platform they intend to support.

Repository-local path setup:

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

External git setup:

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http_native_macos
```

## Example App

See [`example/`](./example) for:

- `HTTP Playground`
- `Benchmark` comparing `nexa_http` vs Dart `HttpClient`

Run focused verification:

```bash
cd packages/nexa_http
fvm dart test

cd packages/nexa_http/example
fvm flutter test
fvm flutter analyze
```

Repository-level verification:

```bash
fvm dart run ../../scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run ../../scripts/workspace_tools.dart verify-development-path
fvm dart run ../../scripts/workspace_tools.dart verify-external-consumer
```

Repository maintainers treat these verification flows as structural checks for
public-surface boundaries, supported native targets, and carrier-produced
artifacts. If you need to change how demo startup, external consumption, or CI
verification works, update the governing OpenSpec specs first instead of editing
the scripts ad hoc.
