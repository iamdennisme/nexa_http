# nexa_http

`nexa_http` is the public Dart package in the `nexa_http` workspace.

## 1. Package Overview

This package is the Flutter-facing entry point of the project.

It provides:

- `NexaHttpClient`
- `NexaHttpRequest`
- `NexaHttpResponse`
- request and response models
- client config and exceptions
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

`NexaHttpClient -> request mapping -> FFI bridge -> registered native runtime -> nexa_http_native_core`

This means the package is responsible for API shape and orchestration, while actual transport execution remains in the native runtime. All supported platforms now use the same async FFI request pipeline.

## 3. Usage

### Release consumption

Recommended production usage is to pin `nexa_http` and the matching platform package to the same git tag:

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
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

dependency_overrides:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
```

At the moment, local `path` consumption still needs the `dependency_overrides` entry for `nexa_http`.

### Client usage

`NexaHttpRequest` currently provides four request helpers: `get`, `post`, `put`, and `delete`.

```dart
import 'dart:convert';

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

Request examples:

```dart
final getResponse = await client.execute(
  NexaHttpRequest.get(
    uri: Uri(path: '/healthz'),
  ),
);

final postResponse = await client.execute(
  NexaHttpRequest.post(
    uri: Uri(path: '/users'),
    headers: {'content-type': 'application/json'},
    bodyBytes: utf8.encode('{"name":"alice"}'),
  ),
);

final putResponse = await client.execute(
  NexaHttpRequest.put(
    uri: Uri(path: '/users/1'),
    headers: {'content-type': 'application/json'},
    bodyBytes: utf8.encode('{"name":"alice-updated"}'),
  ),
);

final deleteResponse = await client.execute(
  NexaHttpRequest.delete(
    uri: Uri(path: '/users/1'),
  ),
);
```

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

- the package worked in external `git + ref: v1.0.0` consumption
- the package also worked in local `path` consumption
- real GET requests through `NexaHttpClient` passed against the fixture server
- real image downloads through the image file service passed

Image benchmark data was captured at the workspace level and is recorded in the root [README](../../README.md).
