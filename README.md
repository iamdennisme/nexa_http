# nexa_http

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP workspace with an OkHttp-style Dart API on top of
a Rust transport runtime.

## Workspace

The repository is split into a small number of responsibilities:

- `packages/nexa_http`: public Dart package used by Flutter apps
- `packages/nexa_http_native_android|ios|macos|windows`: platform carrier
  packages that register and package the native runtime
- `packages/nexa_http/native/rust_net_native`: Rust transport implementation
- `fixture_server/`: local HTTP fixture server used by the example app and tests
- `scripts/`: workspace build and verification helpers

The public mental model is intentionally narrow:

- apps use HTTP concepts only
- carrier packages hide runtime registration
- transport startup stays lazy and internal

## Public API

The root library is [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart).

It exports:

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

Typical usage:

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

`NexaHttpClient` is lightweight and synchronous. Native loading, worker startup,
and pooled transport acquisition happen lazily on the first real
`call.execute()`.

## Platform Packages

End-user application code should stay on `package:nexa_http/nexa_http.dart`.

Carrier packages use `package:nexa_http_runtime/nexa_http_runtime.dart`
internally to register the native runtime. Build hooks use
`package:nexa_http_distribution/nexa_http_distribution.dart`. Neither package
is for normal app code.

## Package Boundaries

The workspace now has three distinct Dart roles:

- `nexa_http`: app-facing HTTP API and transport bridge
- `nexa_http_runtime`: runtime SPI, loader, and host-platform discovery
- `nexa_http_distribution`: native artifact resolution for build hooks and
  release tooling

This split is intentional. `nexa_http` no longer re-exports runtime or
distribution entrypoints.

## Versioning And Releases

The workspace should be treated as one release train.

- Keep `nexa_http`, `nexa_http_runtime`, `nexa_http_distribution`, and the
  carrier packages on the same semantic version.
- Ship native asset releases against that same version tag.
- If a change affects runtime loading, manifest format, or carrier-package
  integration, bump the package set together rather than drifting versions.
- `dart run scripts/workspace_tools.dart verify` now checks package analysis,
  package tests, and release-train version alignment together.
- `dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z`
  verifies that the repository tag matches the aligned package version before
  release publication.
- `dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z`
  creates a temporary external Flutter consumer outside the repository, resolves
  `packages/nexa_http` from the git+ssh tag, runs the minimum host build check,
  and deletes the temporary app on success.

The native-assets workflow in
[`release-native-assets.yml`](./.github/workflows/release-native-assets.yml)
publishes assets by repository tag only after the release-train version check
passes. Use one tag per workspace release.

For an end-to-end governed tag validation run, publish the branch and tag with
[`scripts/tag_release_validation.sh`](./scripts/tag_release_validation.sh), wait
for the tag-triggered workflow to finish, then verify external tag consumption
with `dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z`.

Example workspace dependency setup:

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
```

When consuming from Git instead of `path`, pin `nexa_http` to the desired ref.

Example git dependency setup:

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http
```

## Example App

The demo app lives in [`packages/nexa_http/example`](./packages/nexa_http/example).

It has two pages:

- `HTTP Playground`: build a request with the public API and inspect the real
  response
- `Benchmark`: compare `nexa_http` against Dart `HttpClient` with concurrent
  `bytes` and `image` scenarios

Run the fixture server:

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

Run the example:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

Other supported targets use the same app without source edits:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d windows
fvm flutter run -d android
fvm flutter run -d ios
```

Default local base URLs:

- macOS / Windows host: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Android device with `adb reverse tcp:8080 tcp:8080`: `http://127.0.0.1:8080`
- iOS simulator on the same host: `http://127.0.0.1:8080`

Platform notes:

- macOS / Windows: run the fixture server on the same machine before `flutter run`
- Android emulator: keep the default `10.0.2.2` base URL
- Android device: use `adb reverse tcp:8080 tcp:8080` if the fixture server is on your host machine
- iOS simulator: the default host loopback URL works; for a physical device, pass a reachable host with `--dart-define=NEXA_HTTP_EXAMPLE_BASE_URL=...`

The benchmark page exposes a small set of parameters:

- `baseUrl`
- `scenario`: `bytes` or `image`
- `concurrency`
- `totalRequests`
- `payloadSize`
- `warmupRequests`
- `timeout`

## Verification

The repository's debugging, packaging, release, and external-consumer flows are
treated as governed operating contracts. Before changing those workflows, review
[`docs/runtime-release-contract.md`](./docs/runtime-release-contract.md) and
update the corresponding OpenSpec specs through a new change.

Workspace commands:

```bash
dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-release-consumer
fvm dart run scripts/workspace_tools.dart verify-development-path
```

Focused package commands:

```bash
cd packages/nexa_http
fvm dart test

cd packages/nexa_http/example
fvm flutter test
fvm flutter analyze
```
