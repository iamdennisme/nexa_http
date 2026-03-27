# Nexa HTTP Federated Native Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `rust_net` to `nexa_http` and replatform the repo into a pure Dart public package, a shared Rust core crate, and one Flutter plus Rust implementation package per platform with published-prebuilt native distribution and local override support.

**Architecture:** The final structure moves all shared execution logic into `native/nexa_http_native_core`, keeps `packages/nexa_http` pure Dart, and gives each `packages/nexa_http_native_<platform>` package ownership of its Flutter registration, build hook, and platform Rust crate. Native delivery defaults to prebuilt artifacts resolved by package-local hooks, while local native debugging is enabled through explicit override environment variables rather than forcing app-wide `path:` integration.

**Tech Stack:** Dart 3.11, Flutter 3.35+, Rust 2024, reqwest, Tokio, serde, code_assets, hooks, ffigen, GitHub Actions.

---

## File Map

- Move: `packages/rust_net` -> `packages/nexa_http`
- Move: `packages/rust_net_native_android` -> `packages/nexa_http_native_android`
- Move: `packages/rust_net_native_ios` -> `packages/nexa_http_native_ios`
- Move: `packages/rust_net_native_macos` -> `packages/nexa_http_native_macos`
- Move: `packages/rust_net_native_linux` -> `packages/nexa_http_native_linux`
- Move: `packages/rust_net_native_windows` -> `packages/nexa_http_native_windows`
- Delete: `packages/rust_net_core`
- Delete: `packages/nexa_http/native/rust_net_native`
- Create: `Cargo.toml`
- Create: `native/nexa_http_native_core/Cargo.toml`
- Create: `native/nexa_http_native_core/include/nexa_http_native.h`
- Create: `native/nexa_http_native_core/src/lib.rs`
- Create: `native/nexa_http_native_core/src/api/error.rs`
- Create: `native/nexa_http_native_core/src/api/ffi.rs`
- Create: `native/nexa_http_native_core/src/api/request.rs`
- Create: `native/nexa_http_native_core/src/api/response.rs`
- Create: `native/nexa_http_native_core/src/platform/mod.rs`
- Create: `native/nexa_http_native_core/src/platform/capabilities.rs`
- Create: `native/nexa_http_native_core/src/platform/proxy.rs`
- Create: `native/nexa_http_native_core/src/runtime/client_registry.rs`
- Create: `native/nexa_http_native_core/src/runtime/executor.rs`
- Create: `native/nexa_http_native_core/src/runtime/tokio_runtime.rs`
- Create: `packages/nexa_http/ffigen.yaml`
- Create: `packages/nexa_http/lib/nexa_http.dart`
- Create: `packages/nexa_http/lib/nexa_http_dio.dart`
- Create: `packages/nexa_http/lib/src/loader/nexa_http_platform_registry.dart`
- Create: `packages/nexa_http/lib/src/loader/nexa_http_native_runtime.dart`
- Create: `packages/nexa_http/lib/src/loader/nexa_http_native_library_loader.dart`
- Create: `packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart`
- Create: `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- Create: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs`
- Create: `packages/nexa_http_native_linux/native/nexa_http_native_linux_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/Cargo.toml`
- Modify: `packages/nexa_http_native_<platform>/pubspec.yaml`
- Modify: `packages/nexa_http_native_<platform>/hook/build.dart`
- Modify: `packages/nexa_http_native_<platform>/lib/*.dart`
- Modify: `scripts/build_native_common.sh`
- Modify: `scripts/build_native_android.sh`
- Modify: `scripts/build_native_ios.sh`
- Modify: `scripts/build_native_linux.sh`
- Modify: `scripts/build_native_macos.sh`
- Modify: `scripts/build_native_windows.sh`
- Modify: `scripts/generate_native_asset_manifest.dart`
- Modify: `scripts/prepare_distribution.dart`
- Modify: `scripts/materialize_distribution.dart`
- Modify: `.github/workflows/release-native-assets.yml`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`
- Modify: `test/materialize_distribution_test.dart`
- Modify: `test/prepare_distribution_test.dart`
- Modify: `test/workspace_tools_test.dart`

## Implementation Notes

- Do not hand-edit generated files such as `*.freezed.dart` or the generated Dart FFI bindings.
- Generate Dart bindings from `native/nexa_http_native_core/include/nexa_http_native.h`.
- The public package must not keep a build hook after this refactor.
- The iOS package must use an Apple-compatible linking model and `DynamicLibrary.process()` on the Dart side.
- Keep commit scope narrow. Each task below should land as its own commit.

## Target Shape

```text
Cargo.toml

native/
  nexa_http_native_core/
    Cargo.toml
    include/
      nexa_http_native.h
    src/
      lib.rs
      api/
      platform/
      runtime/

packages/
  nexa_http/
  nexa_http_native_android/
    native/nexa_http_native_android_ffi/
  nexa_http_native_ios/
    native/nexa_http_native_ios_ffi/
  nexa_http_native_macos/
    native/nexa_http_native_macos_ffi/
  nexa_http_native_linux/
    native/nexa_http_native_linux_ffi/
  nexa_http_native_windows/
    native/nexa_http_native_windows_ffi/
```

### Task 1: Rename the package family and lock the new workspace shape

**Files:**
- Create: `test/workspace_package_layout_test.dart`
- Move: `packages/rust_net` -> `packages/nexa_http`
- Move: `packages/rust_net_native_android` -> `packages/nexa_http_native_android`
- Move: `packages/rust_net_native_ios` -> `packages/nexa_http_native_ios`
- Move: `packages/rust_net_native_macos` -> `packages/nexa_http_native_macos`
- Move: `packages/rust_net_native_linux` -> `packages/nexa_http_native_linux`
- Move: `packages/rust_net_native_windows` -> `packages/nexa_http_native_windows`
- Delete: `packages/rust_net_core`
- Modify: `pubspec.yaml`
- Modify: `scripts/workspace_tools.dart`
- Modify: `test/workspace_tools_test.dart`
- Modify: `packages/nexa_http/example/pubspec.yaml`
- Modify: `packages/nexa_http/example/rust_net_dio_consumer/pubspec.yaml`

- [ ] **Step 1: Write a failing workspace layout test**

Create `test/workspace_package_layout_test.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('workspace exposes only the nexa_http package family', () {
    final packagesDir = Directory(p.join(Directory.current.path, 'packages'));
    final packageNames = packagesDir
        .listSync()
        .whereType<Directory>()
        .map((dir) => File(p.join(dir.path, 'pubspec.yaml')))
        .where((file) => file.existsSync())
        .map((file) => (loadYaml(file.readAsStringSync()) as YamlMap)['name'])
        .whereType<String>()
        .toSet();

    expect(packageNames, contains('nexa_http'));
    expect(packageNames, contains('nexa_http_native_android'));
    expect(packageNames, contains('nexa_http_native_ios'));
    expect(packageNames, contains('nexa_http_native_macos'));
    expect(packageNames, contains('nexa_http_native_linux'));
    expect(packageNames, contains('nexa_http_native_windows'));
    expect(packageNames, isNot(contains('rust_net')));
    expect(packageNames, isNot(contains('rust_net_core')));
  });
}
```

- [ ] **Step 2: Run the workspace layout test to verify it fails**

Run:

```bash
dart test test/workspace_package_layout_test.dart -r expanded
```

Expected:

- FAIL because the repo still contains `rust_net` package names
- FAIL because `rust_net_core` still exists

- [ ] **Step 3: Rename directories and package names**

Apply the package-family rename with `git mv` and update every `name:` field and path dependency:

```bash
git mv packages/rust_net packages/nexa_http
git mv packages/rust_net_native_android packages/nexa_http_native_android
git mv packages/rust_net_native_ios packages/nexa_http_native_ios
git mv packages/rust_net_native_macos packages/nexa_http_native_macos
git mv packages/rust_net_native_linux packages/nexa_http_native_linux
git mv packages/rust_net_native_windows packages/nexa_http_native_windows
git rm -r packages/rust_net_core
```

Then update:

- root `pubspec.yaml` to `name: nexa_http_workspace`
- every moved package `pubspec.yaml`
- example path dependencies under `packages/nexa_http/example/...`
- `scripts/workspace_tools.dart` and `test/workspace_tools_test.dart` expectations

- [ ] **Step 4: Re-run the workspace layout tests**

Run:

```bash
dart test test/workspace_package_layout_test.dart test/workspace_tools_test.dart -r expanded
```

Expected:

- PASS
- `discoverWorkspacePackageDirs` returns only `nexa_http` family paths

- [ ] **Step 5: Commit the rename-only workspace change**

Run:

```bash
git add pubspec.yaml scripts/workspace_tools.dart test/workspace_package_layout_test.dart \
  test/workspace_tools_test.dart packages/nexa_http packages/nexa_http_native_android \
  packages/nexa_http_native_ios packages/nexa_http_native_macos \
  packages/nexa_http_native_linux packages/nexa_http_native_windows
git commit -m "refactor(nexa_http): rename package family"
```

### Task 2: Create the shared Rust workspace and freeze the ABI contract

**Files:**
- Create: `native/Cargo.toml`
- Create: `native/nexa_http_native_core/Cargo.toml`
- Create: `native/nexa_http_native_core/include/nexa_http_native.h`
- Create: `native/nexa_http_native_core/src/lib.rs`
- Create: `native/nexa_http_native_core/src/api/error.rs`
- Create: `native/nexa_http_native_core/src/api/ffi.rs`
- Create: `native/nexa_http_native_core/src/api/request.rs`
- Create: `native/nexa_http_native_core/src/api/response.rs`
- Create: `native/nexa_http_native_core/src/platform/mod.rs`
- Create: `native/nexa_http_native_core/src/platform/capabilities.rs`
- Create: `native/nexa_http_native_core/src/platform/proxy.rs`
- Create: `native/nexa_http_native_core/src/runtime/client_registry.rs`
- Create: `native/nexa_http_native_core/src/runtime/executor.rs`
- Create: `native/nexa_http_native_core/src/runtime/tokio_runtime.rs`
- Create: `native/nexa_http_native_core/tests/runtime_smoke.rs`
- Create: `native/nexa_http_native_core/tests/proxy_runtime.rs`

- [ ] **Step 1: Write failing Rust tests against the new core crate**

Add repo-root `Cargo.toml` with only the workspace shell plus a `nexa_http_native_core` member, and create tests that reference items not implemented yet.

`native/nexa_http_native_core/tests/runtime_smoke.rs`:

```rust
use nexa_http_native_core::platform::{PlatformCapabilities, ProxySettings};
use nexa_http_native_core::runtime::NexaHttpRuntime;

#[derive(Clone, Default)]
struct TestCapabilities;

impl PlatformCapabilities for TestCapabilities {
    fn proxy_settings(&self) -> ProxySettings {
        ProxySettings::default()
    }
}

#[test]
fn runtime_creates_a_client_registry() {
    let runtime = NexaHttpRuntime::new(TestCapabilities);
    assert_eq!(runtime.client_count_for_test(), 0);
}
```

`native/nexa_http_native_core/tests/proxy_runtime.rs`:

```rust
use nexa_http_native_core::platform::ProxySettings;

#[test]
fn proxy_settings_signature_is_stable() {
    let settings = ProxySettings::default();
    assert_eq!(settings.signature_for_test(), "http=|https=|all=|no=");
}
```

- [ ] **Step 2: Run the new Rust tests to verify they fail**

Run:

```bash
cargo test --manifest-path Cargo.toml -p nexa_http_native_core
```

Expected:

- FAIL because the crate is incomplete
- Missing modules, missing types, or missing helper methods such as `client_count_for_test`

- [ ] **Step 3: Implement the shared core crate and shared C header**

Build the crate by transplanting pure runtime logic out of the old single crate into the new workspace:

- define `PlatformCapabilities` and `ProxySettings`
- define `NexaHttpRuntime<P>`
- move runtime orchestration and client registry into `src/runtime/`
- move request, response, error, and FFI result types into `src/api/`
- write `include/nexa_http_native.h` as the only ABI source of truth
- keep platform discovery out of the core crate

Use these symbol names in the header:

```c
uint64_t nexa_http_client_create(const char* config_json);
uint8_t nexa_http_client_execute_async(
  uint64_t client_id,
  uint64_t request_id,
  const char* request_json,
  const uint8_t* body_ptr,
  uintptr_t body_len,
  NexaHttpExecuteCallback callback
);
void nexa_http_client_close(uint64_t client_id);
void nexa_http_binary_result_free(NexaHttpBinaryResult* result);
```

- [ ] **Step 4: Run the core Rust tests**

Run:

```bash
cargo test --manifest-path Cargo.toml -p nexa_http_native_core
```

Expected:

- PASS
- New core tests cover runtime creation and stable signature behavior

- [ ] **Step 5: Commit the shared-core extraction**

Run:

```bash
git add Cargo.toml native/nexa_http_native_core
git commit -m "feat(nexa_http): add shared native core workspace"
```

### Task 3: Make `packages/nexa_http` a pure Dart package with registry-based loading

**Files:**
- Create: `packages/nexa_http/ffigen.yaml`
- Create: `packages/nexa_http/lib/nexa_http.dart`
- Create: `packages/nexa_http/lib/nexa_http_dio.dart`
- Create: `packages/nexa_http/lib/src/loader/nexa_http_platform_registry.dart`
- Create: `packages/nexa_http/lib/src/loader/nexa_http_native_runtime.dart`
- Create: `packages/nexa_http/lib/src/loader/nexa_http_native_library_loader.dart`
- Create: `packages/nexa_http/lib/src/native_bridge/nexa_http_native_data_source_factory.dart`
- Create: `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_native_data_source.dart`
- Modify: `packages/nexa_http/pubspec.yaml`
- Modify: `packages/nexa_http/lib/src/api/*.dart`
- Modify: `packages/nexa_http/test/*.dart`
- Delete: `packages/nexa_http/hook/build.dart`
- Delete: `packages/nexa_http/test/build_hook_test.dart`
- Delete: `packages/nexa_http/lib/src/native/rust_net_native_asset_bundle.dart`

- [ ] **Step 1: Write failing Dart tests for the new registry boundary**

Create `packages/nexa_http/test/nexa_http_platform_registry_test.dart`:

```dart
import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:test/test.dart';

void main() {
  test('throws a clear error when no platform runtime is registered', () {
    NexaHttpPlatformRegistry.instance = null;
    expect(
      () => NexaHttpPlatformRegistry.requireInstance(),
      throwsStateError,
    );
  });
}
```

Create `packages/nexa_http/test/nexa_http_native_library_loader_test.dart`:

```dart
import 'dart:ffi';

import 'package:nexa_http/src/loader/nexa_http_native_library_loader.dart';
import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:test/test.dart';

class _FakeRuntime implements NexaHttpNativeRuntime {
  @override
  DynamicLibrary open() => DynamicLibrary.process();
}

void main() {
  test('uses the registered runtime to open the native library', () {
    NexaHttpPlatformRegistry.instance = _FakeRuntime();
    expect(loadNexaHttpDynamicLibrary(), isA<DynamicLibrary>());
  });
}
```

- [ ] **Step 2: Run the new Dart tests to verify they fail**

Run:

```bash
cd packages/nexa_http && dart test test/nexa_http_platform_registry_test.dart test/nexa_http_native_library_loader_test.dart -r expanded
```

Expected:

- FAIL because the new loader classes and helpers do not exist yet

- [ ] **Step 3: Implement the pure Dart package boundary**

Do all of the following without reintroducing native artifact policy into the public package:

- rename public library entrypoints from `rust_net*.dart` to `nexa_http*.dart`
- add the loader and registry layer under `lib/src/loader/`
- rewrite the native data source factory to obtain a `DynamicLibrary` through the registry
- remove the public-package build hook and old asset-bundle logic
- add `packages/nexa_http/ffigen.yaml` pointing at `../../native/nexa_http_native_core/include/nexa_http_native.h`
- regenerate bindings

Run:

```bash
cd packages/nexa_http && dart run ffigen --config ffigen.yaml
cd packages/nexa_http && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run the public package tests**

Run:

```bash
cd packages/nexa_http && dart test -r expanded
```

Expected:

- PASS
- no remaining references to `package:rust_net`

- [ ] **Step 5: Commit the pure-Dart public package refactor**

Run:

```bash
git add packages/nexa_http
git commit -m "refactor(nexa_http): make public package pure dart"
```

### Task 4: Implement the macOS reference platform end-to-end

**Files:**
- Create: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs`
- Create: `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/tests/proxy_settings.rs`
- Create: `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart`
- Modify: `packages/nexa_http_native_macos/pubspec.yaml`
- Modify: `packages/nexa_http_native_macos/hook/build.dart`
- Modify: `packages/nexa_http_native_macos/lib/nexa_http_native_macos.dart`
- Modify: `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_asset_bundle.dart`
- Modify: `packages/nexa_http_native_macos/macos/rust_net_native_macos.podspec`
- Create: `packages/nexa_http_native_macos/test/nexa_http_native_macos_plugin_test.dart`
- Modify: `packages/nexa_http_native_macos/test/build_hook_test.dart`

- [ ] **Step 1: Write failing macOS platform tests**

Create `packages/nexa_http_native_macos/test/nexa_http_native_macos_plugin_test.dart`:

```dart
import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:nexa_http_native_macos/nexa_http_native_macos.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the macOS runtime', () {
    NexaHttpPlatformRegistry.instance = null;
    NexaHttpNativeMacosPlugin.registerWith();
    expect(NexaHttpPlatformRegistry.instance, isNotNull);
  });
}
```

Create `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/tests/proxy_settings.rs`:

```rust
use nexa_http_native_macos_ffi::current_proxy_settings_for_test;

#[test]
fn maps_apple_values_into_proxy_settings() {
    let settings = current_proxy_settings_for_test(
        Some("secure-proxy.example.com"),
        Some(8443),
        true,
        None,
        None,
        false,
    );
    assert_eq!(settings.https.as_deref(), Some("http://secure-proxy.example.com:8443/"));
}
```

- [ ] **Step 2: Run the macOS tests to verify they fail**

Run:

```bash
cd packages/nexa_http_native_macos && dart test test/nexa_http_native_macos_plugin_test.dart test/build_hook_test.dart -r expanded
cargo test --manifest-path packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml
```

Expected:

- FAIL because the plugin registration class and Rust crate do not exist yet

- [ ] **Step 3: Implement the macOS package and platform crate**

Implement:

- a Dart registration class that sets `NexaHttpPlatformRegistry.instance`
- `pubspec.yaml` plugin metadata with Dart registration plus FFI packaging
- a package-local build hook that compiles or resolves the macOS native artifact
- `nexa_http_native_macos_ffi` depending on `native/nexa_http_native_core`
- Apple `SystemConfiguration`-based capability implementation
- uniform exported C ABI forwarding into `NexaHttpRuntime`

- [ ] **Step 4: Run macOS package verification**

Run:

```bash
cd packages/nexa_http_native_macos && dart test -r expanded
cargo test --manifest-path packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml
./scripts/build_native_macos.sh debug
```

Expected:

- Dart tests PASS
- Rust tests PASS
- `./scripts/build_native_macos.sh debug` prints `Prepared` for a `nexa_http_native_macos` artifact path

- [ ] **Step 5: Commit the macOS reference implementation**

Run:

```bash
git add packages/nexa_http_native_macos scripts/build_native_macos.sh scripts/build_native_common.sh Cargo.toml
git commit -m "feat(nexa_http_native_macos): add reference platform runtime"
```

### Task 5: Port the Linux and Windows platform packages

**Files:**
- Create: `packages/nexa_http_native_linux/native/nexa_http_native_linux_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_linux/native/nexa_http_native_linux_ffi/src/lib.rs`
- Create: `packages/nexa_http_native_linux/lib/src/nexa_http_native_linux_plugin.dart`
- Modify: `packages/nexa_http_native_linux/pubspec.yaml`
- Modify: `packages/nexa_http_native_linux/hook/build.dart`
- Modify: `packages/nexa_http_native_linux/lib/nexa_http_native_linux.dart`
- Modify: `packages/nexa_http_native_linux/test/build_hook_test.dart`
- Create: `packages/nexa_http_native_linux/test/nexa_http_native_linux_plugin_test.dart`
- Create: `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/lib.rs`
- Create: `packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart`
- Modify: `packages/nexa_http_native_windows/pubspec.yaml`
- Modify: `packages/nexa_http_native_windows/hook/build.dart`
- Modify: `packages/nexa_http_native_windows/lib/nexa_http_native_windows.dart`
- Modify: `packages/nexa_http_native_windows/test/build_hook_test.dart`
- Create: `packages/nexa_http_native_windows/test/nexa_http_native_windows_plugin_test.dart`

- [ ] **Step 1: Write failing Linux and Windows registration tests**

Add `packages/nexa_http_native_linux/test/nexa_http_native_linux_plugin_test.dart` and `packages/nexa_http_native_windows/test/nexa_http_native_windows_plugin_test.dart` using the same pattern as the macOS registration test.

Also add Rust parsing tests:

- `packages/nexa_http_native_linux/native/nexa_http_native_linux_ffi/tests/proxy_settings.rs`
- `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/tests/proxy_settings.rs`

The Windows test should assert that split `ProxyServer` entries map correctly into shared `ProxySettings`.

- [ ] **Step 2: Run the Linux and Windows tests to verify they fail**

Run:

```bash
cd packages/nexa_http_native_linux && dart test test/nexa_http_native_linux_plugin_test.dart test/build_hook_test.dart -r expanded
cd packages/nexa_http_native_windows && dart test test/nexa_http_native_windows_plugin_test.dart test/build_hook_test.dart -r expanded
cargo test --manifest-path packages/nexa_http_native_linux/native/nexa_http_native_linux_ffi/Cargo.toml
cargo test --manifest-path packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/Cargo.toml
```

Expected:

- FAIL because the new registration classes and Rust crates do not exist yet

- [ ] **Step 3: Implement both desktop platform packages**

Implement:

- Linux package-local plugin registration and build hook
- Linux platform crate with the V1 empty-or-env-only capability implementation
- Windows package-local plugin registration and build hook
- Windows platform crate with registry-backed proxy discovery
- workspace membership updates in repo-root `Cargo.toml`

- [ ] **Step 4: Run Linux and Windows verification**

Run:

```bash
cd packages/nexa_http_native_linux && dart test -r expanded
cd packages/nexa_http_native_windows && dart test -r expanded
cargo test --manifest-path Cargo.toml -p nexa_http_native_linux_ffi -p nexa_http_native_windows_ffi
./scripts/build_native_linux.sh debug
./scripts/build_native_windows.sh debug
```

Expected:

- package tests PASS
- workspace cargo tests PASS
- build scripts print `Prepared` artifact paths for Linux and Windows

- [ ] **Step 5: Commit the Linux and Windows ports**

Run:

```bash
git add packages/nexa_http_native_linux packages/nexa_http_native_windows Cargo.toml \
  scripts/build_native_linux.sh scripts/build_native_windows.sh
git commit -m "feat(nexa_http): add linux and windows runtimes"
```

### Task 6: Port the iOS and Android platform packages

**Files:**
- Create: `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs`
- Create: `packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart`
- Modify: `packages/nexa_http_native_ios/pubspec.yaml`
- Modify: `packages/nexa_http_native_ios/hook/build.dart`
- Modify: `packages/nexa_http_native_ios/lib/nexa_http_native_ios.dart`
- Modify: `packages/nexa_http_native_ios/ios/rust_net_native_ios.podspec`
- Modify: `packages/nexa_http_native_ios/test/build_hook_test.dart`
- Create: `packages/nexa_http_native_ios/test/nexa_http_native_ios_plugin_test.dart`
- Create: `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/Cargo.toml`
- Create: `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/lib.rs`
- Create: `packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart`
- Modify: `packages/nexa_http_native_android/pubspec.yaml`
- Modify: `packages/nexa_http_native_android/hook/build.dart`
- Modify: `packages/nexa_http_native_android/lib/nexa_http_native_android.dart`
- Modify: `packages/nexa_http_native_android/android/build.gradle`
- Modify: `packages/nexa_http_native_android/test/build_hook_test.dart`
- Create: `packages/nexa_http_native_android/test/nexa_http_native_android_plugin_test.dart`

- [ ] **Step 1: Write failing iOS and Android package tests**

Add registration tests for both packages using the same `NexaHttpPlatformRegistry` pattern.

Add Rust tests:

- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/tests/proxy_settings.rs`
- `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/tests/proxy_settings.rs`

The Android test should assert mapping from `getprop`-style keys into the shared `ProxySettings`.

- [ ] **Step 2: Run the mobile package tests to verify they fail**

Run:

```bash
cd packages/nexa_http_native_ios && dart test test/nexa_http_native_ios_plugin_test.dart test/build_hook_test.dart -r expanded
cd packages/nexa_http_native_android && dart test test/nexa_http_native_android_plugin_test.dart test/build_hook_test.dart -r expanded
cargo test --manifest-path packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/Cargo.toml
cargo test --manifest-path packages/nexa_http_native_android/native/nexa_http_native_android_ffi/Cargo.toml
```

Expected:

- FAIL because the mobile registration and native crates are not implemented yet

- [ ] **Step 3: Implement the iOS and Android packages**

Implement:

- iOS package-local plugin registration
- iOS build hook and Apple-compatible packaging
- Dart loading via `DynamicLibrary.process()` on iOS
- Android package-local plugin registration
- Android build hook and Gradle wiring for packaged `.so` artifacts
- both platform crates depending on `nexa_http_native_core`

- [ ] **Step 4: Run mobile verification**

Run:

```bash
cd packages/nexa_http_native_ios && dart test -r expanded
cd packages/nexa_http_native_android && dart test -r expanded
cargo test --manifest-path Cargo.toml -p nexa_http_native_ios_ffi -p nexa_http_native_android_ffi
./scripts/build_native_ios.sh debug
./scripts/build_native_android.sh debug
```

Expected:

- package tests PASS
- workspace cargo tests PASS
- iOS build script stages Apple-compatible artifacts
- Android build script stages ABI-specific `.so` files under `nexa_http_native_android`

- [ ] **Step 5: Commit the iOS and Android ports**

Run:

```bash
git add packages/nexa_http_native_ios packages/nexa_http_native_android Cargo.toml \
  scripts/build_native_ios.sh scripts/build_native_android.sh
git commit -m "feat(nexa_http): add ios and android runtimes"
```

### Task 7: Rebuild build hooks, manifest generation, and local override flows

**Files:**
- Modify: `packages/nexa_http_native_android/hook/build.dart`
- Modify: `packages/nexa_http_native_ios/hook/build.dart`
- Modify: `packages/nexa_http_native_macos/hook/build.dart`
- Modify: `packages/nexa_http_native_linux/hook/build.dart`
- Modify: `packages/nexa_http_native_windows/hook/build.dart`
- Modify: `scripts/build_native_common.sh`
- Modify: `scripts/generate_native_asset_manifest.dart`
- Modify: `scripts/prepare_distribution.dart`
- Modify: `scripts/materialize_distribution.dart`
- Modify: `test/materialize_distribution_test.dart`
- Modify: `test/prepare_distribution_test.dart`

- [ ] **Step 1: Write failing distribution tests for the new package names and override variables**

Update `test/prepare_distribution_test.dart` and `test/materialize_distribution_test.dart` so they expect:

- `nexa_http_native_<platform>` package names
- artifacts under the new package paths
- support for:
  - `NEXA_HTTP_NATIVE_<PLATFORM>_SOURCE_DIR`
  - `NEXA_HTTP_NATIVE_<PLATFORM>_LIB_PATH`
  - `NEXA_HTTP_NATIVE_MANIFEST_PATH`
  - `NEXA_HTTP_NATIVE_RELEASE_BASE_URL`

Example expectation:

```dart
expect(requestedPackages, contains('nexa_http_native_macos'));
expect(environmentOverrides, contains('NEXA_HTTP_NATIVE_MACOS_LIB_PATH'));
```

- [ ] **Step 2: Run the root distribution tests to verify they fail**

Run:

```bash
dart test test/prepare_distribution_test.dart test/materialize_distribution_test.dart -r expanded
```

Expected:

- FAIL because scripts still reference `rust_net` paths and old manifest conventions

- [ ] **Step 3: Implement the new distribution model**

Update:

- all package hooks to prefer prebuilt artifact download by package version
- hook fallback to local source or local library when override variables are present
- manifest generation to emit `nexa_http`-family file names and checksums
- materialization scripts to copy only the renamed package family
- build scripts to compile each package-local Rust crate rather than the deleted single crate

- [ ] **Step 4: Re-run the distribution tests**

Run:

```bash
dart test test/prepare_distribution_test.dart test/materialize_distribution_test.dart -r expanded
```

Expected:

- PASS
- tests assert both published-artifact and local-override paths

- [ ] **Step 5: Commit the distribution and hook rewrite**

Run:

```bash
git add scripts test packages/nexa_http_native_android/hook/build.dart \
  packages/nexa_http_native_ios/hook/build.dart packages/nexa_http_native_macos/hook/build.dart \
  packages/nexa_http_native_linux/hook/build.dart packages/nexa_http_native_windows/hook/build.dart
git commit -m "feat(nexa_http): add prebuilt and local override distribution flow"
```

### Task 8: Update release automation for prebuilt native publishing

**Files:**
- Modify: `.github/workflows/release-native-assets.yml`

- [ ] **Step 1: Write a failing release-workflow smoke assertion**

Add `test/release_workflow_layout_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('release workflow publishes nexa_http native artifacts', () {
    final workflow = File('.github/workflows/release-native-assets.yml').readAsStringSync();
    expect(workflow, contains('nexa_http_native'));
    expect(workflow, isNot(contains('packages/rust_net/native/rust_net_native')));
  });
}
```

- [ ] **Step 2: Run the workflow smoke test to verify it fails**

Run:

```bash
dart test test/release_workflow_layout_test.dart -r expanded
```

Expected:

- FAIL because the workflow still references `packages/rust_net/native/rust_net_native`

- [ ] **Step 3: Rewrite the release workflow**

Update `.github/workflows/release-native-assets.yml` so it:

- builds `packages/nexa_http_native_<platform>/native/nexa_http_native_<platform>_ffi`
- stages artifacts from the new package-local output directories
- generates a manifest using the `nexa_http` family naming
- uploads release artifacts and manifest together

- [ ] **Step 4: Re-run the release workflow smoke test**

Run:

```bash
dart test test/release_workflow_layout_test.dart -r expanded
```

Expected:

- PASS

- [ ] **Step 5: Commit the release automation update**

Run:

```bash
git add .github/workflows/release-native-assets.yml test/release_workflow_layout_test.dart
git commit -m "ci(nexa_http): publish prebuilt native artifacts"
```

### Task 9: Delete the legacy layout, update docs and examples, and run the full verification matrix

**Files:**
- Delete: `packages/nexa_http/native/rust_net_native`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `packages/nexa_http/README.md`
- Modify: `packages/nexa_http/example/pubspec.yaml`
- Modify: `packages/nexa_http/example/test/*`
- Modify: `packages/nexa_http/example/lib/src/image_perf/rust_net_image_file_service.dart`
- Modify: `packages/nexa_http/test/*`

- [ ] **Step 1: Update example and docs tests first**

Rename example imports and dependency references to the `nexa_http` family, then update example and package tests to import `package:nexa_http/...` instead of `package:rust_net/...`.

At minimum update:

- `packages/nexa_http/example/pubspec.yaml`
- `packages/nexa_http/example/test/`
- `packages/nexa_http/test/`
- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http/README.md`

- [ ] **Step 2: Run the example and package tests to verify the rename still has gaps**

Run:

```bash
cd packages/nexa_http && dart test example/test test -r expanded
```

Expected:

- FAIL until all example imports, docs snippets, and remaining test names are updated

- [ ] **Step 3: Remove legacy directories and finish the doc rewrite**

Delete the last legacy native tree:

```bash
git rm -r packages/nexa_http/native/rust_net_native
```

Then make the docs match the final integration model:

- published packages plus prebuilt assets by default
- Git dependencies for unpublished app trials
- `path:` only for workspace development
- local native override environment variables for debugging

- [ ] **Step 4: Run the full verification matrix**

Run:

```bash
dart pub get
dart run scripts/workspace_tools.dart bootstrap
dart run scripts/workspace_tools.dart analyze
dart run scripts/workspace_tools.dart test
cargo test --manifest-path Cargo.toml --workspace
```

Then run the native build scripts relevant to the current host and CI matrix:

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_linux.sh debug
./scripts/build_native_windows.sh debug
./scripts/build_native_ios.sh debug
./scripts/build_native_android.sh debug
```

Expected:

- workspace analyze PASS
- workspace tests PASS
- Rust workspace tests PASS
- each build script prints `Prepared` for the renamed package paths or the CI equivalent passes on its host runner

- [ ] **Step 5: Commit the cleanup and final verification**

Run:

```bash
git add README.md README.zh-CN.md packages/nexa_http docs/superpowers/specs \
  scripts .github test
git commit -m "refactor(nexa_http): finalize federated native architecture"
```
