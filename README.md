# nexa_http

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP SDK with an OkHttp-style Dart API and a Rust-powered transport core.

It is built for apps that want a straightforward Dart request API while keeping the transport layer in native code.

## Why use it

- A small, app-facing Dart API
- Rust-powered transport under the hood
- Explicit platform packages for Android, iOS, macOS, and Windows
- A demo app you can run locally to exercise the full Flutter → FFI → Rust path

## Supported platforms

- Android
- iOS
- macOS
- Windows

## Architecture

The monorepo has two main layers:

- **Flutter SDK layer**: `packages/nexa_http`, `packages/nexa_http_native_internal`, platform carrier packages, build hooks, and verification tooling.
- **Native layer**: the shared Rust core, platform FFI crates, and native build scripts.

Platform carriers, build hooks, release assets, and clean-host verification are mechanisms that connect those two layers. They are not separate app-facing APIs.

The [architecture index](./docs/architecture.md) links the bounded contexts, accepted ADRs, package specs, authority order, and current review evidence.

## Installation

A normal app imports only `package:nexa_http/nexa_http.dart` in runtime code,
but its `pubspec.yaml` declares both `nexa_http` and the platform package for
each target it ships.

### Git dependency

Use a real published release tag. The example below uses `v2.0.3`.

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v2.0.3
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v2.0.3
      path: packages/nexa_http_native_macos
```

Declare the carrier package for every platform the app builds:

| Target | Carrier dependency path |
| --- | --- |
| Android | `packages/nexa_http_native_android` |
| iOS | `packages/nexa_http_native_ios` |
| macOS | `packages/nexa_http_native_macos` |
| Windows | `packages/nexa_http_native_windows` |

All Git dependencies must use the same repository URL and release tag. A
multi-platform app declares each carrier it targets, while application code
still imports only `package:nexa_http/nexa_http.dart`.

### Local path dependency

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

## Quick start

The public entrypoint is [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart).

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('my-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/healthz'))
    .header('accept', 'application/json')
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
await client.close();
```

Calls and response bodies are one-shot. Reuse a `Request` by creating a new
call, and consume each response body once with `bytes()` or `string()`.

## Demo

The official demo lives in [`app/demo`](./app/demo).

Start the local fixture server from the repository root:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

For repository development, run the demo through the standard Flutter toolchain.
The carrier hook builds the requested Rust target into target-scoped hook
output and passes that exact file to Flutter Native Assets:

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

The demo includes:

- `HTTP Playground`
- `Benchmark`

More run details are in [`app/demo/README.md`](./app/demo/README.md).

## Packages

Flutter SDK layer:

- `packages/nexa_http` — public Dart SDK
- `packages/nexa_http_native_internal` — shared ABI types, bindings registry, target matrix, and artifact materialization helper
- `packages/nexa_http_native_android` — Android carrier
- `packages/nexa_http_native_ios` — iOS carrier
- `packages/nexa_http_native_macos` — macOS carrier
- `packages/nexa_http_native_windows` — Windows carrier

Native layer:

- `native/nexa_http_native_core` — shared Rust transport core
- `packages/nexa_http_native_*/native/*_ffi` — platform FFI crates

Release builds publish native download assets on GitHub Releases. Carrier build hooks download and verify those assets into target-scoped hook output. Flutter Native Assets is the only packaging/loading authority; carrier-owned `@Native` bindings resolve the matching CodeAsset ID.

## Development

For maintainers, the most useful local checks are:

```bash
fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux
fvm dart run scripts/workspace_tools.dart matrix --suite verify-integration
fvm dart run scripts/workspace_tools.dart check rust-format --execution static-linux
```

`verify-integration` and `verify-release-candidate` require the explicit
execution, fixture URL, and device inputs printed by their Catalog matrices.
Atomic `check` commands are diagnostics only; CI and release gates use complete
suites.

A fuller verification guide is in [`docs/verification-playbook.md`](./docs/verification-playbook.md).

## Native release transaction

Native releases use one immutable transaction workflow:
`.github/workflows/release-native-assets.yml`. Pull requests run a real,
non-publishing rehearsal. A manual dispatch requires a stable version, a full
40-character commit SHA, and an explicit `publish` boolean.

The workflow builds three canonical platform fragments, assembles one private
candidate artifact, and runs blocking Android, iOS, macOS, and Windows
clean-host gates over that exact artifact ID and digest. Only a manual dispatch
with `publish=true` can reach the publisher. The publisher does not rebuild,
rename, copy, or regenerate candidate files; it revalidates and uploads the
same bytes under their original names.

There is no tag-push release path, compatibility workflow, fallback publisher,
or draft/prerelease staging path. A failed rehearsal or gate leaves only
private Actions diagnostics and creates no public tag or GitHub Release.

## License

[LICENSE](./LICENSE)
