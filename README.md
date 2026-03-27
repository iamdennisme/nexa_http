# rust_net workspace

[中文文档](./README.zh-CN.md)


### Project Overview

`rust_net` is a Flutter HTTP SDK workspace that keeps business-facing APIs in
Dart while delegating transport execution to a Rust `reqwest` core.

This repository is designed for:

- Dart API and Flutter transport facade (`rust_net`)
- platform carrier packages for native delivery
- native Rust transport runtime and multi-platform packaging
- local fixture/proxy tools for integration testing

### Repository Contents

- `packages/rust_net`: Flutter package, FFI bridge, and Dio adapter
- `packages/rust_net_native_android|ios|macos|windows|linux`: carrier packages for platform artifacts and build hooks
- `packages/rust_net/native/rust_net_native`: Rust `cdylib` based on `reqwest`
- `fixture_server/`: local HTTP fixture server and proxy smoke-test tooling
- `scripts/`: multi-platform native build scripts

### Package Details

- `packages/rust_net`: the only public Dart API package, including requests, responses, exceptions, FFI bridge, and `Dio` integration.
- `packages/rust_net_native_*`: thin Flutter/pub carrier packages for platform-specific native artifacts.

### Local development

```bash
dart pub get
dart run scripts/workspace_tools.dart bootstrap
dart run scripts/workspace_tools.dart analyze
dart run scripts/workspace_tools.dart test
```

### Build Native Libraries

When Rust native code changes, rebuild the platform artifacts into the carrier
package directories. These outputs are build products and should not be
committed:

```bash
./scripts/build_native_all.sh release
```

You can also build one platform at a time:

```bash
./scripts/build_native_macos.sh
./scripts/build_native_android.sh
./scripts/build_native_linux.sh
./scripts/build_native_ios.sh
./scripts/build_native_windows.sh
```

To build the selected carrier artifacts and then materialize a separate
publish/debug workspace:

```bash
dart run scripts/prepare_distribution.dart \
  --packages=rust_net,rust_net_native_android,rust_net_native_macos
```

If the artifacts already exist locally, you can materialize only:

```bash
dart run scripts/materialize_distribution.dart \
  --packages=rust_net,rust_net_native_android,rust_net_native_macos
```

Android notes:

- The Android carrier package materializes `jniLibs` during the build workflow.
- It falls back to source build only when any ABI library is missing, or when `RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` is set.
- Source fallback requires Rust toolchain + Android NDK on the build machine.

### Use In Flutter

`pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^2.0.0
  rust_net_native_android: ^2.0.0 # choose the carrier packages you ship
```

Use as a Dio adapter:

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

Use the core client directly:

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(baseUrl: Uri.parse('https://api.example.com/')),
);
final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);
await client.close();
```

### Local Integration

For local app debugging, there are two recommended modes.

Use the source workspace when you want to iterate on this repository directly:

```yaml
dependencies:
  rust_net:
    path: /absolute/path/to/rust_net/packages/rust_net
  rust_net_native_macos:
    path: /absolute/path/to/rust_net/packages/rust_net_native_macos
```

Before running the consumer app, bootstrap the workspace and build the matching
carrier artifacts:

```bash
dart run scripts/workspace_tools.dart bootstrap
./scripts/build_native_macos.sh debug
```

Use the materialized distribution workspace when you want something closer to
what will later be uploaded to pub or shared as local `path` dependencies:

```bash
dart run scripts/prepare_distribution.dart \
  --packages=rust_net,rust_net_native_macos
```

Then point the consumer app to `.dist/materialized_workspace/packages/...`:

```yaml
dependencies:
  rust_net:
    path: /absolute/path/to/rust_net/.dist/materialized_workspace/packages/rust_net
  rust_net_native_macos:
    path: /absolute/path/to/rust_net/.dist/materialized_workspace/packages/rust_net_native_macos
```

Only include the carrier packages for the platforms you actually need to ship.

### Proxy Behavior

- Proxy selection runs in Rust for every request.
- If the proxy snapshot changes, `rust_net` rebuilds the underlying `reqwest::Client`.
- If no proxy is detected, requests go direct.
- Priority is: platform system proxy first, then env fallback.
- Env fallback keys: `HTTP_PROXY`/`http_proxy`, `HTTPS_PROXY`/`https_proxy`, `ALL_PROXY`/`all_proxy`, `NO_PROXY`/`no_proxy`.

Platform proxy sources:

- Android: `getprop` (`http.proxyHost`, `https.proxyHost`, `socksProxyHost`, `*.nonProxyHosts`)
- iOS/macOS: Apple `SystemConfiguration`
- Windows: `Internet Settings` registry
- Other targets: env fallback only
- Current scope is manual HTTP/HTTPS/SOCKS proxy settings; PAC is not evaluated yet

### Network Test Tooling

All local network test utilities are grouped under `fixture_server/`:

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

To run only Rust crate compile locally:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### Prebuilt strategy

Native artifacts are generated into carrier package directories during build:

- Android: `packages/rust_net_native_android/android/src/main/jniLibs/*/librust_net_native.so`
- iOS: `packages/rust_net_native_ios/ios/Frameworks/*.dylib`
- Linux: `packages/rust_net_native_linux/linux/Libraries/librust_net_native.so`
- macOS: `packages/rust_net_native_macos/macos/Libraries/librust_net_native.dylib`
- Windows: `packages/rust_net_native_windows/windows/Libraries/rust_net_native.dll`

`packages/rust_net_native_android/android/build.gradle` uses locally built `jniLibs` when present and falls back to Rust compilation only when they are missing.

To force source rebuild on Android:

```bash
RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true flutter build apk
```

### Compatibility shim

`packages/rust_net_core` remains in the repository as a deprecated shim package.
It re-exports `package:rust_net` for migration compatibility and should not be
used for new integrations.
