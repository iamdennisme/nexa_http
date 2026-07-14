# Project Layering Spec Draft

## Status

Confirmed by user and used as the documentation/spec update baseline.

This document defines the monorepo-level architecture in coarse project layers. Fine-grained names such as `carrier`, `internal native layer`, `FFI crate`, `release artifact`, and `clean-host consumer` are mechanisms inside the two main layers, not top-level architecture layers.

## Current Code Fit

The current code mostly matches a two-layer monorepo architecture:

```text
nexa_http monorepo
├── Flutter SDK layer
└── Native layer
```

Confirmed evidence:

- `packages/nexa_http/pubspec.yaml` defines the app-facing package `nexa_http` and depends on `nexa_http_native_internal`.
- `packages/nexa_http/lib/nexa_http.dart` exports only the public Dart API and client entrypoint.
- `packages/nexa_http_native_<platform>/pubspec.yaml` declares `implements: nexa_http`, which makes each platform package the Flutter platform implementation for the app-facing SDK package.
- `packages/nexa_http_native_<platform>/lib/src/*_plugin.dart` registers a platform native runtime loader strategy through `nexa_http_native_internal`.
- `packages/nexa_http_native_<platform>/hook/build.dart` prepares either workspace-built artifacts or release artifacts, then exposes them to Flutter code assets.
- `native/nexa_http_native_core` contains shared Rust runtime, FFI data structures, request execution, cancellation, callback, errors, and proxy abstractions.
- `packages/nexa_http_native_<platform>/native/*_ffi` exports the uniform `nexa_http_*` C ABI and binds shared Rust core to platform proxy sources.
- `scripts/workspace_tools.dart` builds clean external consumers with only `nexa_http` plus the host platform carrier dependency; generated `main.dart` imports only `package:nexa_http/nexa_http.dart`.

Important correction to older wording:

- `release artifact`, `native artifact`, `build hook`, and `clean-host consumer` are not independent architecture layers. They are packaging, distribution, or verification mechanisms for connecting the Flutter SDK layer to the native layer.

## Layer 1: Flutter SDK Layer

### Scope

The Flutter SDK layer contains the Dart/Flutter-facing side of the product:

- `packages/nexa_http`
- `packages/nexa_http_native_internal`
- `packages/nexa_http_native_android`
- `packages/nexa_http_native_ios`
- `packages/nexa_http_native_macos`
- `packages/nexa_http_native_windows`
- `scripts/workspace_tools.dart`
- carrier `hook/build.dart`
- README and consumer verification docs

### Responsibilities

The Flutter SDK layer owns:

- Public Dart HTTP API exposed to app code.
- SDK package composition for Flutter consumers.
- Mapping Dart requests/configuration/errors to native FFI calls.
- Flutter plugin identity for `nexa_http`.
- Platform implementation selection through explicit platform carrier packages.
- Runtime dynamic library strategy registration.
- Native artifact packaging into Flutter build outputs.
- Release artifact materialization and checksum verification.
- Clean-host consumer verification.

### Internal Roles

`packages/nexa_http` is the app-facing SDK package.

- Owns public API: `NexaHttpClient`, `Request`, `Response`, `Call`, `Headers`, `NexaHttpException`, etc.
- Owns root import: `package:nexa_http/nexa_http.dart`.
- May own Flutter plugin identity metadata.
- Must not expose native artifact paths, plugin registration helpers, release manifest parsing, or FFI lifecycle as app-facing API.

`packages/nexa_http_native_internal` is the SDK's internal native helper package.

- Owns dynamic library loader, runtime registry, target matrix, release manifest parsing, artifact download/materialization, checksum verification, and workspace/release detection helpers.
- Is consumed by `nexa_http`, carrier packages, and workspace scripts.
- Must not be documented as app runtime API.

`packages/nexa_http_native_<platform>` packages are platform carrier packages.

- Own Flutter platform implementation for one target platform.
- Own plugin registration, build hook, native asset packaging, and platform-specific runtime loader strategy.
- Must not own public HTTP API or request execution semantics.

`scripts/workspace_tools.dart` and related Dart scripts are verification/distribution tooling.

- Own repository checks, artifact consistency checks, clean external consumer checks, and release consumer checks.
- Must model the expected external app integration contract.

## Layer 2: Native Layer

### Scope

The native layer contains the Rust and platform-native side of the product:

- `native/nexa_http_native_core`
- `packages/nexa_http_native_android/native/nexa_http_native_android_ffi`
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi`
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi`
- `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi`
- `scripts/build_native_android.sh`
- `scripts/build_native_ios.sh`
- `scripts/build_native_macos.sh`
- `scripts/build_native_windows.sh`
- `scripts/build_native_all.sh`

### Responsibilities

The native layer owns:

- Shared Rust HTTP runtime.
- Uniform C ABI exported as `nexa_http_*`.
- FFI request/response/error data structures.
- Native memory ownership and free functions.
- Client registry, async execution, cancellation, callback, and result free.
- Native error JSON contract.
- Shared proxy model and proxy matching.
- OS-specific proxy discovery in platform FFI crates.
- Native dynamic library artifacts for supported target platforms.

### Internal Roles

`native/nexa_http_native_core` is the shared Rust core.

- Owns shared request execution, error model, FFI data structures, ownership rules, runtime registry, and proxy abstraction.
- Must not read OS-specific proxy sources directly.
- Must not search workspace, pub-cache, release assets, or package artifact paths.

Platform FFI crates are native platform adapters.

- Own C ABI export glue.
- Own platform proxy source implementation.
- Bind `nexa_http_native_core` to platform runtime state.
- Produce platform dynamic libraries.
- Must not duplicate shared HTTP runtime logic.
- Must not implement Dart build hooks or release artifact download.

Native build scripts prepare platform artifacts from Rust crates.

- They are maintainer/development/release tooling, not host app integration steps.
- Normal external apps should not run these scripts.

## Boundary Between Flutter SDK Layer And Native Layer

The two layers combine through three contracts:

### 1. Public SDK Contract

External app runtime code imports only:

```dart
import 'package:nexa_http/nexa_http.dart';
```

External app runtime code must not import:

- `package:nexa_http_native_internal/...`
- `package:nexa_http_native_android/...`
- `package:nexa_http_native_ios/...`
- `package:nexa_http_native_macos/...`
- `package:nexa_http_native_windows/...`

### 2. FFI ABI Contract

The Flutter SDK layer calls the native layer through the uniform `nexa_http_*` C ABI.

The ABI owns:

- `nexa_http_client_create`
- `nexa_http_client_execute_async`
- `nexa_http_client_cancel_request`
- `nexa_http_client_close`
- `nexa_http_binary_result_free`
- request body allocation/free functions
- string/error ownership functions

Any ABI change must update Rust core, every platform FFI crate, generated Dart bindings, Dart mappers/decoders, and tests.

### 3. Artifact Packaging Contract

The native layer produces dynamic libraries.

The Flutter SDK layer packages those dynamic libraries into Flutter build outputs through carrier packages and build hooks.

External apps must not copy native files or modify native build projects manually.

## Final Output Shape

Status: revised after user review.

The repository has two externally meaningful output categories, plus one build-time materialized result.

### 1. SDK Packages

Consumer-facing packages:

- `nexa_http`
- one or more target platform carrier packages:
  - `nexa_http_native_android`
  - `nexa_http_native_ios`
  - `nexa_http_native_macos`
  - `nexa_http_native_windows`

Internal package:

- `nexa_http_native_internal`

The internal package is a dependency of SDK/carrier packages, not a package external app code imports.

### 2. Published Native Download Assets

GitHub Release assets include:

- `nexa_http-native-android-arm64-v8a.so`
- `nexa_http-native-android-armeabi-v7a.so`
- `nexa_http-native-android-x86_64.so`
- `nexa_http-native-ios-arm64.dylib`
- `nexa_http-native-ios-sim-arm64.dylib`
- `nexa_http-native-ios-sim-x64.dylib`
- `nexa_http-native-macos-arm64.dylib`
- `nexa_http-native-macos-x64.dylib`
- `nexa_http-native-windows-x64.dll`
- `nexa_http_native_assets_manifest.json`
- `SHA256SUMS`

The manifest maps target OS, architecture, optional SDK, file name, source URL, and checksum. Carrier build hooks materialize the right artifact for the current target.

### Build-Time Materialized Native Libraries

Platform dynamic libraries are not a separate externally published output category. They are the build-time result that carrier hooks place into package/App-internal layout paths.

They come from one of two sources:

- Workspace development: carrier hook runs `scripts/build_native_<platform>.sh debug`, then places the locally built dynamic library into the carrier layout.
- Release consumer: carrier hook downloads the matching published native download asset, verifies checksum, then places it into the carrier layout.

Materialized layout examples:

- Android:
  - `android/src/main/jniLibs/arm64-v8a/libnexa_http_native.so`
  - `android/src/main/jniLibs/armeabi-v7a/libnexa_http_native.so`
  - `android/src/main/jniLibs/x86_64/libnexa_http_native.so`
- iOS:
  - `ios/Frameworks/libnexa_http_native-ios-arm64.dylib`
  - `ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib`
  - `ios/Frameworks/libnexa_http_native-ios-sim-x64.dylib`
- macOS:
  - `macos/Libraries/libnexa_http_native.dylib`
- Windows:
  - `windows/Libraries/nexa_http_native.dll`

External apps should not create or copy these files manually.

## External App Integration Contract

Status: confirmed by user.

An external Flutter app integrates the SDK by declaring dependencies and using only the public Dart SDK API.

The important distinction is:

- `pubspec.yaml` declares both `nexa_http` and the target platform carrier package.
- Runtime Dart code imports only `package:nexa_http/nexa_http.dart`.
- Carrier packages are dependency artifacts and Flutter platform implementations, not runtime APIs for app code.

### Git Dependency Example

Use a real published release tag.

```yaml
dependencies:
  flutter:
    sdk: flutter
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http_native_macos
```

For another platform, replace the carrier package with the target platform package.

### Runtime Code Example

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('my-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/healthz'))
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
```

### Host App Must Not

- Import carrier packages in runtime code.
- Import `nexa_http_native_internal`.
- Manually register plugins.
- Copy `.so`, `.dylib`, or `.dll` files.
- Modify Podfile, Gradle, CMake, Xcode project, or Visual Studio project for standard integration.
- Run repository build scripts as part of normal app integration.

### Expected Integration Flow

```text
external Flutter app
  -> declare nexa_http + target carrier dependency
  -> flutter pub get
  -> import package:nexa_http/nexa_http.dart
  -> flutter build / flutter run
  -> carrier hook materializes/packages native artifact
  -> carrier plugin registers native runtime loader
  -> nexa_http executes requests through native layer
```

## Current Mismatches And Follow-Up Fixes

The code mostly fits this architecture. Follow-up work should align the AI-facing and human-facing documentation:

- `.trellis/spec/` should be rewritten around the two top-level layers and their internal mechanisms.
- `CONTEXT.md` should explain English terms under the two main project layers.
- README and verification docs should use the confirmed two-layer architecture and real release-tag examples for copyable Git dependency snippets.
- Trellis package discovery currently only covers Rust crates. It should cover the Flutter SDK layer packages or provide an explicit shared guide that future AI sessions always load for Flutter SDK/package work.
- macOS/iOS/Windows FFI specs should be brought up to the Android FFI spec's specificity for proxy fields, test injection, and refresh mode.
