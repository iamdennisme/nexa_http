# nexa_http verification playbook

This document captures the current end-to-end verification workflow for `nexa_http`.

It is written so another AI agent or developer can run the same checks on another machine, including Windows.

## Core rule

Runtime integration should consume prepared native artifacts only.

Source compilation is still useful, but only as an explicit preparation step for repository maintainers.

That means:

- app/demo and external apps consume packaged binaries
- hooks resolve packaged binaries
- Rust / NDK / platform toolchains are for preparing artifacts, not for normal app integration

## Preparing local artifacts for repository development

If you are debugging native code locally, prepare fresh artifacts first, then run the app.

Platform-specific commands:

### macOS

```bash
./scripts/build_native_macos.sh debug
```

### iOS

```bash
./scripts/build_native_ios.sh debug
```

### Windows

```bash
./scripts/build_native_windows.sh debug
```

### Android

```bash
./scripts/build_native_android.sh debug
```

After that, run the Flutter app normally. The app should consume the prepared binaries instead of rebuilding Rust during app integration.

## What this playbook verifies

There are three different integration layers to verify:

1. **Workspace demo path**
   - Uses the repository demo in `app/demo`
   - Verifies local development flow
2. **External consumer path**
   - Uses a temporary Flutter app outside the workspace
   - Verifies consumer-style integration through git dependencies
3. **Manual git+tag consumer path**
   - Uses a temporary Flutter app outside the workspace
   - Verifies a real app that depends on a released tag

## Prerequisites

- Flutter toolchain managed by `fvm`
- Rust toolchain installed
- Platform toolchains available for the target you want to validate
- Git access to `git@github.com:iamdennisme/nexa_http.git`

## Repository-level checks

Run these from the repository root:

```bash
fvm dart pub get
fvm dart test test/workspace_tools_test.dart test/workspace_demo_and_consumer_verification_test.dart test/workspace_package_layout_test.dart test/fixture_image_lookup_test.dart
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

What they prove:

- target matrix and release workflow stay aligned
- the official demo still works as a workspace app
- a temporary external consumer can resolve and build against the repository

## Official demo verification

Start the local fixture server:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

Then run the official demo:

### macOS / Windows

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

### Android emulator

Use the Android emulator base URL:

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d <android-device-id> --dart-define=NEXA_HTTP_DEMO_BASE_URL=http://10.0.2.2:8080
```

### Android device

```bash
adb reverse tcp:8080 tcp:8080
cd app/demo
fvm flutter pub get
fvm flutter run -d <android-device-id> --dart-define=NEXA_HTTP_DEMO_BASE_URL=http://127.0.0.1:8080
```

## Manual git+tag consumer verification

Create a temporary Flutter app outside the workspace and depend on a released tag.

Current tag under test:

- `v1.0.2`

Example `pubspec.yaml` dependencies for macOS:

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

Then run:

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run -d macos --dart-define=NEXA_HTTP_GIT_TAG_DEMO_REQUEST_URL=https://www.baidu.com
```

For automatic one-shot verification, let the app print the request result and exit.

Expected success output contains:

```text
NEXA_HTTP_GIT_TAG_DEMO_STATUS=200
```

## Important macOS note

For a macOS app to issue outbound requests, its entitlements must include:

- `com.apple.security.network.client`

This is required for both workspace demos and standalone consumer demos.

## Windows validation guidance

A Windows machine or Windows runner should validate:

```bash
fvm dart pub get
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
```

If you want a standalone Windows consumer app, create a Flutter Windows project and depend on:

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http
  nexa_http_native_windows:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http_native_windows
```

Then run:

```bash
fvm flutter pub get
fvm flutter run -d windows
```

## Android validation guidance

If an Android emulator is already running:

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d emulator-5554 --dart-define=NEXA_HTTP_DEMO_BASE_URL=http://10.0.2.2:8080
```

If no emulator is running:

```bash
fvm flutter emulators --launch Medium_Phone
```

Then rerun the command above.

## Release validation

After pushing a release tag, verify:

- CI workflow on `main` passes
- release workflow for the tag passes
- release assets exist for Android / iOS / macOS / Windows
- `nexa_http_native_assets_manifest.json` exists
- `SHA256SUMS` exists

## Current known-good evidence

Validated in this repository session:

- `v1.0.2` release published successfully
- external macOS git+tag consumer app built and ran
- git+tag consumer request to `https://www.baidu.com` returned HTTP 200
- workspace CI passed on macOS / Ubuntu / Windows after the Windows hook fix
