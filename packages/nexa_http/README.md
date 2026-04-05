# nexa_http

`nexa_http` is the public Dart SDK in this repository.

If you are integrating the project into an app, this is the package your application code talks to.

## What it gives you

- An app-facing HTTP API in Dart
- A request-building style that feels familiar if you have used OkHttp before
- A Rust-powered transport layer behind the scenes
- Platform carrier packages for Android, iOS, macOS, and Windows

Entrypoint:

```dart
import 'package:nexa_http/nexa_http.dart';
```

## Dependency model

A normal app uses:

1. `nexa_http`
2. the carrier packages for the platforms it ships

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

## Public API

The package exposes the core request and response types you use directly:

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

## What stays internal

Application code should not need to handle:

- runtime registration
- dynamic-library loading details
- platform-specific startup logic
- artifact layout inside the carrier packages

Those concerns live behind `nexa_http` and the platform carriers.

## Demo

The official demo app is in [`../../app/demo`](../../app/demo).

Useful local commands:

```bash
cd packages/nexa_http
fvm dart test

cd ../../app/demo
fvm flutter test
fvm flutter analyze
```

## More docs

- Workspace overview: [`../../README.md`](../../README.md)
- Demo guide: [`../../app/demo/README.md`](../../app/demo/README.md)
- Verification guide: [`../../docs/verification-playbook.md`](../../docs/verification-playbook.md)
