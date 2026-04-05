# nexa_http

`nexa_http` is the public Dart SDK in this repository.

If you are integrating this library into an application, this is the package you write code against.

## What you use directly

`nexa_http` exposes the app-facing HTTP API, including:

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

Entrypoint:

```dart
import 'package:nexa_http/nexa_http.dart';
```

## What stays internal

Application code should not need to deal with:

- native runtime registration
- dynamic-library loading details
- platform-specific startup logic
- internal artifact layout

Those concerns are handled by:

- `packages/nexa_http_native_internal`
- the platform carrier packages

## Dependency model

To integrate `nexa_http`, add:

1. `nexa_http`
2. the platform carrier packages for the targets your app supports

### Local path setup

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

### Git setup

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

## Example

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

## Demo

The official demo app lives at [`../../app/demo`](../../app/demo).

Useful local commands:

```bash
cd packages/nexa_http
fvm dart test

cd ../../app/demo
fvm flutter test
fvm flutter analyze
```

## Repository verification

From the repository root:

```bash
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

## Architecture note

`nexa_http` is the only public Dart API surface.

The full stack behind it is:

- `nexa_http` — public SDK
- `nexa_http_native_internal` — internal native runtime/loading layer
- `nexa_http_native_<platform>` — platform carriers
- `nexa_http_native_core` — shared Rust core
