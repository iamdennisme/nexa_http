# nexa_http

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP SDK with an OkHttp-style Dart API backed by a Rust transport runtime.

It is meant to keep app-facing usage small:

- depend on `nexa_http`
- declare the `nexa_http_native_<platform>` packages for the platforms your app supports
- import `package:nexa_http/nexa_http.dart`
- build requests with a familiar HTTP API
- let the SDK keep native startup lazy behind the public API surface

## Install

For normal app code, declare:

- `nexa_http` as the public Dart API package
- `nexa_http_native_<platform>` for each target platform your app supports

### Git / SSH dependency

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

The public entrypoint is [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart).

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

App code should not need to import platform carrier packages for API usage, nor deal with runtime strategy registration, native library loading, or release asset lookup directly. Platform packages are public dependency artifacts selected at app integration time, while production loading follows a fixed loading contract behind the public Dart API surface.

## Try The Demo

The repository demo lives in [`packages/nexa_http/example`](./packages/nexa_http/example).

Start the local fixture server from the repository root:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

Then run the example app:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

The demo includes:

- `HTTP Playground` — send real requests with the public API
- `Benchmark` — compare `nexa_http` and Dart `HttpClient`

For platform-specific setup, benchmark options, and environment variables, see:

- [`packages/nexa_http/example/README.md`](./packages/nexa_http/example/README.md)

## Notes

- Repository-local demo and development use the local workspace source.
- External consumers import `package:nexa_http/nexa_http.dart`, and declare the `nexa_http_native_<platform>` packages for the targets they support.
- Native startup stays lazy behind the SDK API surface, and runtime strategy registration is the only production loading path.

## More Docs

- Package guide: [`packages/nexa_http/README.md`](./packages/nexa_http/README.md)
- Demo guide: [`packages/nexa_http/example/README.md`](./packages/nexa_http/example/README.md)

## Repository Layout

If you are just consuming the SDK, you can stop here.

- `packages/nexa_http` — public SDK surface
- `packages/nexa_http_native_runtime_internal` — internal native runtime/loading layer used by `nexa_http`
- `packages/nexa_http_native_android|ios|macos|windows` — platform carrier packages that produce artifacts
- `native/nexa_http_native_core` — shared Rust core
