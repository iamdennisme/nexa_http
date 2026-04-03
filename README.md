# nexa_http

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP SDK with an OkHttp-style Dart API backed by a Rust transport runtime.

If you're integrating it into an app, the mental model is intentionally small:

- depend on `nexa_http`
- import `package:nexa_http/nexa_http.dart`
- build requests with the public HTTP API
- let the workspace handle native runtime registration, artifact resolution, and platform wiring internally

Most of this repository exists so application code does **not** need to think about native loading and release plumbing.

## Use It In An App

For normal app code, `nexa_http` is the only package you should declare.

### Git / SSH dependency

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http
```

### Local path dependency

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
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

### What app code does **not** need to handle

You should not need to care about:

- platform carrier packages
- runtime registration
- native library loading
- release manifest lookup
- release asset download rules

Those concerns live behind the package boundary.

## Run The Demo

The demo app lives in [`packages/nexa_http/example`](./packages/nexa_http/example).

It has two pages:

- **HTTP Playground** — build a real request with the public API and inspect the response
- **Benchmark** — compare `nexa_http` and Dart `HttpClient` under the same concurrent workload

### 1. Start the local fixture server

From the repository root:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

If your local Dart toolchain already matches the repo requirement, `dart run` also works. `fvm` is the safer default for this repository.

### 2. Run the example app

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

Other supported targets use the same project without source edits:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d windows
fvm flutter run -d android
fvm flutter run -d ios
```

### Common local base URLs

- macOS / Windows host: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Android device with `adb reverse tcp:8080 tcp:8080`: `http://127.0.0.1:8080`
- iOS simulator on the same host: `http://127.0.0.1:8080`

### Platform notes

- macOS / Windows: run the fixture server on the same machine before `flutter run`
- Android emulator: keep the default `10.0.2.2` base URL
- Android device: use `adb reverse tcp:8080 tcp:8080` if the fixture server runs on your host machine
- iOS simulator: the default host loopback URL works
- Physical devices: pass a reachable host with `--dart-define=NEXA_HTTP_EXAMPLE_BASE_URL=...`

## Benchmark

The benchmark page compares `nexa_http` and Dart `HttpClient` sequentially, so one run does not steal bandwidth or sockets from the other.

### Scenarios

- `bytes` — hits `/bytes?size=...&seed=...`
- `image` — hits `/image?id=...`

### Configurable inputs

- `baseUrl`
- `scenario`
- `concurrency`
- `totalRequests`
- `payloadSize`
- `warmupRequests`
- `timeout`

### Reported metrics

Each transport reports:

- total duration
- throughput (`MiB/s`)
- requests per second
- first-request latency
- post-warmup average latency
- P50 latency
- P95 latency
- P99 latency
- max latency
- success count
- failure count
- failure breakdown
- bytes received

The example also supports benchmark defaults through `--dart-define` values such as:

- `NEXA_HTTP_EXAMPLE_BASE_URL`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_SCENARIO`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_CONCURRENCY`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_TOTAL_REQUESTS`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_PAYLOAD_SIZE`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_WARMUP_REQUESTS`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_TIMEOUT_MS`
- `NEXA_HTTP_EXAMPLE_AUTO_RUN_BENCHMARK`
- `NEXA_HTTP_EXAMPLE_EXIT_AFTER_BENCHMARK`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_OUTPUT_PATH`

See [`packages/nexa_http/example/README.md`](./packages/nexa_http/example/README.md) for example launch commands.

## Consume From A Release Tag

This repository treats the workspace as a single release train.

That means:

- `nexa_http`
- `nexa_http_runtime`
- `nexa_http_distribution`
- all platform carrier packages

move together on the same semantic version.

Release assets are published by GitHub Actions against the same repository tag.

### Tag rules

- keep release-train package versions aligned
- publish one workspace tag per release
- use the same tag for git consumption and release asset publication

Before publishing, the repository checks tag/version parity with:

```bash
fvm dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z
```

To prove a tag is externally consumable, the repository also supports:

```bash
fvm dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z
```

That command creates a temporary Flutter app outside the repository, resolves `packages/nexa_http` from the git+ssh tag, runs the minimum host build check, and deletes the temporary app on success.

For the full governed flow, use:

```bash
./scripts/tag_release_validation.sh run --tag vX.Y.Z --remote origin --branch develop
```

That script is the repository-owned entrypoint for:

- pushing the branch
- recreating a governed tag if needed
- publishing the tag
- waiting for the tag-triggered release workflow

## Maintainer Workflows

This repository treats debugging, packaging, release, and external-consumer flows as governed operating contracts.

If you change those workflows, update the corresponding OpenSpec specs first.

### Workspace-level commands

```bash
fvm dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-release-consumer
fvm dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z
```

### Focused package checks

```bash
cd packages/nexa_http
fvm dart test

cd packages/nexa_http/example
fvm flutter test
fvm flutter analyze
```

### Release publication workflow

The tag-triggered release workflow lives at:

- [`.github/workflows/release-native-assets.yml`](./.github/workflows/release-native-assets.yml)

The broader workflow contract is documented here:

- [`docs/runtime-release-contract.md`](./docs/runtime-release-contract.md)

## Workspace Layout

If you're just consuming the SDK, you can stop reading here. The rest of this section is mainly for repository maintainers.

### Dart packages

- `packages/nexa_http` — public app-facing HTTP API
- `packages/nexa_http_runtime` — runtime SPI, loader behavior, and host-platform discovery
- `packages/nexa_http_distribution` — native artifact resolution and release-manifest logic
- `packages/nexa_http_native_android|ios|macos|windows` — platform carrier packages that register and package the runtime

### Rust code

The shared Rust core lives in:

- `native/nexa_http_native_core`

Platform-specific native crates live under the carrier packages, for example:

- `packages/nexa_http_native_macos/native/...`
- `packages/nexa_http_native_ios/native/...`
- `packages/nexa_http_native_android/native/...`
- `packages/nexa_http_native_windows/native/...`

### Local fixtures and scripts

- `fixture_server/` — local HTTP fixture server used by the example app and tests
- `scripts/` — workspace build, verification, release, and tag-validation helpers

## Design Intent

The repository is intentionally split so app-facing usage stays narrow:

- apps use HTTP concepts
- platform packages hide runtime registration
- transport startup stays lazy and internal
- release-consumer behavior stays explicit
- release assets are governed by repository-owned workflows, not ad hoc local steps

That separation is what lets the public SDK stay small even though the workspace itself has a fair amount of native and release machinery behind it.
