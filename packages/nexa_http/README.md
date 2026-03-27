# nexa_http

`nexa_http` is the public Dart package in the `nexa_http` workspace.

It provides:

- `NexaHttpClient`
- `NexaHttpRequest`
- `NexaHttpResponse`
- `NexaHttpDioAdapter`

It does not build or locate native binaries by itself. Native loading now happens through the matching platform package:

- `nexa_http_native_android`
- `nexa_http_native_ios`
- `nexa_http_native_macos`
- `nexa_http_native_linux`
- `nexa_http_native_windows`

## Usage

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      tag_pattern: 'v{{version}}'
      path: packages/nexa_http
    version: ^1.0.0
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      tag_pattern: 'v{{version}}'
      path: packages/nexa_http_native_macos
    version: ^1.0.0
```

```dart
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

```dart
import 'package:dio/dio.dart';
import 'package:nexa_http/nexa_http_dio.dart';

final dio = Dio()
  ..httpClientAdapter = NexaHttpDioAdapter.client(
    config: NexaHttpClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

## Package internals

- public API and models stay in Dart
- FFI bindings are generated from `native/nexa_http_native_core/include/nexa_http_native.h`
- the package uses a registry-based native runtime loader
- platform packages register their runtime into `nexa_http`

## Local verification

```bash
fvm dart test
```

Native integration tests in this package use a host test runtime helper and expect the platform binary to exist. On macOS, the usual workflow is:

```bash
./scripts/build_native_macos.sh debug
cd packages/nexa_http
fvm dart test
```
