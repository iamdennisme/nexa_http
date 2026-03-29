# nexa_http workspace

[中文](./README.zh-CN.md)

`nexa_http` is a Flutter HTTP SDK workspace built around:

- a pure Dart public package
- a shared Rust native core
- one Flutter plus Rust platform package per target platform

The public Dart API stays in Dart. Transport execution stays in Rust.

## Workspace layout

- `packages/nexa_http`: public Dart API, request models, and FFI bindings
- `packages/nexa_http_native_android|ios|macos|linux|windows`: platform carrier packages, build hooks, and platform Rust runtimes
- `native/nexa_http_native_core`: shared Rust core runtime and ABI contract
- `fixture_server/`: local HTTP fixture server and proxy smoke tooling
- `scripts/`: native build, distribution, and workspace helper scripts

Active tracked workspace packages are the `nexa_http*` packages above. If you still have local `packages/rust_net*` directories on disk, treat them as legacy residue from the earlier rename and not as part of the current workspace layout.

## Architecture

- `nexa_http` is pure Dart. It no longer builds, downloads, or discovers native artifacts by itself.
- `nexa_http_native_core` is a pure Rust core crate. It owns runtime logic, proxy policy, DTOs, and the shared C ABI.
- Each `nexa_http_native_<platform>` package owns:
  - Flutter registration for that platform
  - the platform build hook
  - the platform Rust crate
  - delivery of the final packaged native binary

Consuming apps explicitly choose the platform packages they ship.

## Consume from another app

Recommended production setup uses git dependencies pinned to a release tag:

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http
  nexa_http_native_android:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http_native_android
  nexa_http_native_ios:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http_native_ios
```

For a different fixed release, change `ref:` consistently across every package.

Notes:

- Pin every package to the same `ref`.
- Add only the carrier packages you actually ship.
- For desktop targets, use the corresponding `nexa_http_native_<platform>` package from the same repo in the same way.
- This is the validated release-consumption path. Carrier packages fetch prebuilt native assets from the GitHub Release manifest for the same tag.

For local workspace development you can use `path` dependencies instead:

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

Path mode notes:

- Today, local `path` consumption still needs a `dependency_overrides` entry for `nexa_http` because carrier packages pin `nexa_http` through git in their own `pubspec.yaml`.
- The override is only needed for local development; the recommended release path remains `git + ref`.

Use the Dart API directly:

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

## Native delivery modes

The intended priority is:

1. Published packages plus prebuilt native artifacts
2. Git dependencies plus prebuilt native artifacts
3. Local workspace development with path dependencies
4. Local native override for debugging

The release-validated path today is item 2.

Platform hooks currently support these overrides:

- `NEXA_HTTP_NATIVE_<PLATFORM>_LIB_PATH`
- `NEXA_HTTP_NATIVE_<PLATFORM>_SOURCE_DIR`
- `NEXA_HTTP_NATIVE_MANIFEST_PATH`
- `NEXA_HTTP_NATIVE_RELEASE_BASE_URL`

Notes:

- `LIB_PATH` points directly at a concrete native binary.
- `SOURCE_DIR` points at the platform Rust crate root and expects built outputs to already exist under its `target/` tree or the repo-root `target/` tree.
- `MANIFEST_PATH` and `RELEASE_BASE_URL` drive manifest-based artifact download.

## Local development

Bootstrap the Dart and Flutter packages:

```bash
dart pub get
dart run scripts/workspace_tools.dart bootstrap
```

Run root Dart tests:

```bash
fvm dart test test
```

Run package tests:

```bash
cd packages/nexa_http && fvm dart test
cd packages/nexa_http/example && fvm flutter test
```

Run the Rust workspace tests:

```bash
cargo test --workspace
```

## Build native artifacts locally

Build all supported platform artifacts:

```bash
./scripts/build_native_all.sh debug
```

Or build one platform:

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_linux.sh debug
./scripts/build_native_windows.sh debug
./scripts/build_native_ios.sh debug
./scripts/build_native_android.sh debug
```

Artifacts are staged into the platform packages:

- Android: `packages/nexa_http_native_android/android/src/main/jniLibs/*/libnexa_http_native.so`
- iOS: `packages/nexa_http_native_ios/ios/Frameworks/*.dylib`
- Linux: `packages/nexa_http_native_linux/linux/Libraries/libnexa_http_native.so`
- macOS: `packages/nexa_http_native_macos/macos/Libraries/libnexa_http_native.dylib`
- Windows: `packages/nexa_http_native_windows/windows/Libraries/nexa_http_native.dll`

These binaries are build outputs and should not be committed.

## Distribution helpers

Prepare a publish-like local workspace:

```bash
dart run scripts/prepare_distribution.dart \
  --packages=nexa_http,nexa_http_native_macos
```

Materialize without rebuilding:

```bash
dart run scripts/materialize_distribution.dart \
  --packages=nexa_http,nexa_http_native_macos
```

Generate the native asset manifest:

```bash
dart run scripts/generate_native_asset_manifest.dart \
  --version 1.0.0
```

## Fixture server

Use the local fixture server for HTTP and proxy verification:

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

This binds to `127.0.0.1` by default.

Use these base URLs depending on the client you run:

- Host-local desktop app: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Android device over `adb reverse`: `http://127.0.0.1:8080` after `adb reverse tcp:8080 tcp:8080`
- Physical device over LAN: start the fixture server with `--host 0.0.0.0` and use your host LAN IP, for example `http://192.168.1.16:8080`

## Demo Verification Report

Verified on 2026-03-29 with:

- Git-based external sample pinned to `v1.0.0`
- Path-based external sample pointed at the local workspace
- macOS desktop target
- local fixture server at `http://127.0.0.1:8080`

HTTP demo verification:

- `git` sample: passed real fixture GET verification through `NexaHttpClient`
- `path` sample: passed real fixture GET verification through `NexaHttpClient`
- Both samples passed external Flutter test suites, including the added host smoke tests

Image-performance demo verification:

- The existing image-performance page was reused unchanged
- Both samples passed widget and logic tests for the image demo
- Real image downloads through `NexaHttpImageFileService` passed in both samples
- Release-consumption benchmark was captured from the external `git` sample on macOS in debug mode using the `image` autorun scenario with `24` fixture images

Observed benchmark results:

| Transport | First screen | Avg latency | P95 latency | Throughput | Requests | Failures |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `defaultHttp` | `802 ms` | `39 ms` | `61 ms` | `35.58 MiB/s` | `24` | `0` |
| `rustNet` | `313 ms` | `9 ms` | `22 ms` | `75.40 MiB/s` | `24` | `0` |

Benchmark command template:

```bash
cd /path/to/your/external_git_sample
env PUB_HOSTED_URL=https://pub.dev \
  FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
  fvm flutter run -d macos \
  --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_SCENARIO=image \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_TRANSPORT=nexa_http \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_IMAGE_COUNT=24
```

Notes:

- These numbers are local debug-build measurements, not a release benchmark.
- In this verification run, `rustNet` outperformed the default image transport on first-screen latency, average latency, P95 latency, and throughput.
- Local `path` consumption also passed, but it currently needs a `dependency_overrides` entry for `nexa_http`.
- The temporary validation apps used for this run were disposable and are not kept in the repository.
