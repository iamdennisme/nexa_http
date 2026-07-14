# nexa_http

`nexa_http` is the public Dart SDK in this repository.

If you are integrating the project into an app, this is the package your application code talks to.

## What it gives you

- An app-facing HTTP API in Dart
- A request-building style that feels familiar if you have used OkHttp before
- A Rust-powered transport layer behind the scenes
- Explicit platform carrier packages for Android, iOS, macOS, and Windows

Entrypoint:

```dart
import 'package:nexa_http/nexa_http.dart';
```

## Dependency model

A normal app imports only `package:nexa_http/nexa_http.dart` in runtime code,
but its `pubspec.yaml` declares both `nexa_http` and the platform package for
each target it ships.

`nexa_http_native_internal` is an internal helper dependency. Application code
should not depend on it directly or import it.

### Local path setup

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

### Git setup

Use a real published release tag. The example below uses `v2.0.0`.

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v2.0.0
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v2.0.0
      path: packages/nexa_http_native_macos
```

When consuming a Git tag, the platform carrier package resolves its native binaries from the GitHub Release assets published for that same tag.

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
await client.close();
```

`Call` is one-shot. To repeat a `Request`, create another call with
`client.newCall(request)`. `ResponseBody` is also one-shot: consume it once with
`bytes()` or `string()`, or call `close()` without reading it.

Byte-backed request bodies transfer ownership explicitly:

```dart
import 'dart:typed_data';

final payload = Uint8List.fromList(<int>[1, 2, 3]);
final body = RequestBody.takeBytes(
  payload,
  contentType: MediaType.parse('application/octet-stream'),
);
// Do not mutate payload after ownership has transferred to RequestBody.
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
- `NexaHttpException`
- `NexaHttpFailureKind`

Application control flow should switch on `NexaHttpException.kind`. Native
codes and FFI stages, when present, are diagnostics rather than stable public
failure categories.

## What stays internal

Application code should not need to handle:

- runtime registration
- dynamic-library loading details
- platform-specific startup logic
- artifact layout inside the platform packages
- release asset download or checksum verification

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
