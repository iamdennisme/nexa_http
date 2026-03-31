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

- runtime registration
- worker lifecycle
- native-library loading
- manual startup or shutdown APIs

Carrier packages handle runtime registration through
`package:nexa_http/nexa_http_platform.dart`.

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

## Platform Packages

This package is only the public Dart API. Apps also need the matching carrier
package for the platforms they ship.

Example workspace setup:

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
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
