# rust_net workspace

[中文文档](./README.zh-CN.md)


### Project Overview

`rust_net` is a Flutter HTTP SDK workspace that keeps business-facing APIs in
Dart while delegating transport execution to a Rust `reqwest` core.

This repository is designed for:

- shared domain contracts (`rust_net_core`)
- Flutter FFI transport implementation (`rust_net`)
- native Rust transport runtime and multi-platform packaging
- local fixture/proxy tools for integration testing

### Repository Contents

- `packages/rust_net_core`: domain entities, exceptions, and repository contracts
- `packages/rust_net`: Flutter package, FFI bridge, and Dio adapter
- `packages/rust_net/native/rust_net_native`: Rust `cdylib` based on `reqwest`
- `fixture_server/`: local HTTP fixture server and proxy smoke-test tooling
- `scripts/`: multi-platform native build scripts

### Package Details

- `packages/rust_net_core`: Pure Dart domain contracts and models (`RustNetRequest`, `RustNetResponse`, `RustNetException`, `HttpExecutor`, etc.).
- `packages/rust_net`: Flutter FFI transport implementation backed by Rust `reqwest`, plus `Dio` adapter integration.

### Local development

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

### Build Native Libraries

When Rust native code changes, rebuild binaries and commit updated artifacts:

```bash
./scripts/build_native_all.sh release
git add packages/rust_net/android/src/main/jniLibs \
        packages/rust_net/ios/Frameworks \
        packages/rust_net/macos/Libraries \
        packages/rust_net/linux/Libraries \
        packages/rust_net/windows/Libraries
```

You can also build one platform at a time:

```bash
./scripts/build_native_macos.sh
./scripts/build_native_android.sh
./scripts/build_native_ios.sh
./scripts/build_native_linux.sh
./scripts/build_native_windows.sh
```

Android notes:

- The plugin prefers prebuilt `jniLibs` in the repository.
- It falls back to source build only when any ABI library is missing, or when `RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` is set.
- Source fallback requires Rust toolchain + Android NDK on the build machine.

### Use In Flutter

`pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^0.1.0
  # optional
  rust_net_core: ^0.1.0
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

### Proxy Behavior

- Proxy selection runs in Rust for every request.
- If the proxy snapshot changes, `rust_net` rebuilds the underlying `reqwest::Client`.
- If no proxy is detected, requests go direct.
- Priority is: platform system proxy first, then env fallback.
- Env fallback keys: `HTTP_PROXY`/`http_proxy`, `HTTPS_PROXY`/`https_proxy`, `ALL_PROXY`/`all_proxy`, `NO_PROXY`/`no_proxy`.

Platform proxy sources:

- Android: `getprop` (`http.proxyHost`, `https.proxyHost`, `socksProxyHost`, `*.nonProxyHosts`)
- iOS/macOS: Apple `SystemConfiguration`
- Linux: GNOME `gsettings` with KDE `kreadconfig` fallback
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

This repository commits prebuilt native artifacts directly in source:

- Android: `packages/rust_net/android/src/main/jniLibs/*/librust_net_native.so`
- iOS: `packages/rust_net/ios/Frameworks/*.dylib`
- macOS: `packages/rust_net/macos/Libraries/librust_net_native.dylib`
- Linux: `packages/rust_net/linux/Libraries/librust_net_native.so` (for local/native validation; Linux Flutter plugin wrapper is not declared yet)
- Windows: `packages/rust_net/windows/Libraries/rust_net_native.dll`

`packages/rust_net/android/build.gradle` prefers prebuilt `jniLibs` and falls back to Rust compilation only when prebuilt files are missing.

To force source rebuild on Android:

```bash
RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true flutter build apk
```

### rust_net_core integration

`rust_net_core` remains a separate package under `packages/rust_net_core`. Consumers can reference both packages from this monorepo using git `path` dependencies (as Kino does).
