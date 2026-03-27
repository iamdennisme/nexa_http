# rust_net

[English](#english) | [中文](#中文)

## English

`rust_net` is a Flutter HTTP SDK that keeps the public API in Dart while using
Rust `reqwest` as the execution core.

`rust_net` is now the only public Dart API package. Platform-specific native
artifacts are being moved into separate carrier packages such as
`rust_net_native_android`, `rust_net_native_ios`, and friends.

### What It Does

- Executes HTTP requests in Rust
- Reuses connections and centralizes transport behavior
- Exposes a direct Dart client and a `Dio` adapter
- Surfaces the final effective URL after redirects

The intended layering is:

- Dart owns request composition, adapters, and framework integration
- Rust owns transport execution, redirect following, timeouts, and low-level failures

### Public Surfaces

- `RustNetClient`
- `RustNetRequest`
- `RustNetResponse`
- `RustNetDioAdapter`

### Dio Integration

For projects that already use `Dio`, swap only the adapter:

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
      defaultHeaders: const <String, String>{'x-sdk': 'rust_net'},
    ),
  );
```

If you already own an `HttpExecutor`, wrap it directly:

```dart
final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter(
    executor: myHttpExecutor,
    closeExecutor: false,
  );
```

Adapter notes:

- Supported methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`
- Request bodies are buffered in Dart before being passed to Rust
- Dio timeouts are reduced to a single request timeout for `rust_net`
- Final redirect target is surfaced as `RustNetResponse.finalUri`
- For Dio callers, the final redirect target is also exposed via `x-rust-net-final-uri`
- Cancellation is still best-effort at the Dart boundary

### Proxy Behavior

- Proxy selection runs in Rust for every request
- If the proxy snapshot changes, `rust_net` rebuilds the underlying `reqwest::Client`
- If no proxy is detected, requests go direct
- Priority is: platform system proxy first, then env fallback
- Env fallback keys: `HTTP_PROXY`/`http_proxy`, `HTTPS_PROXY`/`https_proxy`, `ALL_PROXY`/`all_proxy`, `NO_PROXY`/`no_proxy`

Platform proxy sources:

- Android: `getprop` (`http.proxyHost`, `https.proxyHost`, `socksProxyHost`, `*.nonProxyHosts`)
- iOS/macOS: Apple `SystemConfiguration`
- Windows: `Internet Settings` registry
- Other targets: env fallback only
- Current scope is manual HTTP/HTTPS/SOCKS proxy settings; PAC is not evaluated yet

### Platform Notes

Native delivery is being migrated to carrier packages such as:

- `rust_net_native_android`
- `rust_net_native_ios`
- `rust_net_native_macos`
- `rust_net_native_windows`
- `rust_net_native_linux`

The public Dart API remains in `package:rust_net`. The macOS packaged artifact
now lives in `package:rust_net_native_macos`; the other native carrier packages
are being filled out incrementally.

For Android builds, `package:rust_net_native_android` first uses locally built
`jniLibs`. If any ABI library is missing, or
`RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` is set, it falls back to compiling
and packaging `librust_net_native.so` during Gradle `preDebugBuild` /
`preReleaseBuild`. Source fallback requires:

- Rust toolchain available from the build environment
- Android NDK installed
- Rust Android targets available or installable through `rustup`

### Consumer App Setup

`pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^2.0.0
  rust_net_native_android: ^2.0.0 # choose the carrier packages you ship
```

Package the macOS native library for local development:

```bash
dart run rust_net:prepare_macos_native --configuration debug
```

For Android consumer builds, no extra manual packaging step is required once
Rust and the Android NDK are available on the build machine.

For sandboxed macOS apps, ensure the Runner entitlements include
`com.apple.security.network.client`.

### Local Path Integration

If you are debugging against the source workspace directly, point your consumer
app at the source package and the matching carrier package:

```yaml
dependencies:
  rust_net:
    path: /absolute/path/to/rust_net/packages/rust_net
  rust_net_native_macos:
    path: /absolute/path/to/rust_net/packages/rust_net_native_macos
```

Then prepare the matching local artifact before `flutter run`:

```bash
dart run /absolute/path/to/rust_net/scripts/workspace_tools.dart bootstrap
/absolute/path/to/rust_net/scripts/build_native_macos.sh debug
```

If you want a publish-like local dependency layout instead, first materialize a
distribution workspace:

```bash
dart run /absolute/path/to/rust_net/scripts/prepare_distribution.dart \
  --packages=rust_net,rust_net_native_macos
```

Then consume the generated packages:

```yaml
dependencies:
  rust_net:
    path: /absolute/path/to/rust_net/.dist/materialized_workspace/packages/rust_net
  rust_net_native_macos:
    path: /absolute/path/to/rust_net/.dist/materialized_workspace/packages/rust_net_native_macos
```

### Repository Layout

- `packages/rust_net/`: Flutter FFI transport package (this package)
- `packages/rust_net_native_android|ios|macos|windows|linux/`: platform carrier packages
- `packages/rust_net/native/rust_net_native/`: Rust `cdylib` based on `reqwest`
- `fixture_server/`: local fixture server and proxy smoke-test utilities

### Local Development

1. Build Rust:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

2. Bootstrap workspace and regenerate generated files:

```bash
dart pub get
dart run ../../scripts/workspace_tools.dart bootstrap
dart run rust_net:prepare_macos_native --configuration debug
dart run ffigen --config ffigen.yaml
dart run build_runner build --delete-conflicting-outputs
```

3. Run checks:

```bash
cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
dart run ../../scripts/workspace_tools.dart analyze
dart run ../../scripts/workspace_tools.dart test
```

If you need to validate Android packaging end-to-end, run a consumer app build
and verify the APK contains `lib/*/librust_net_native.so`.

For monorepo local development, this package lives at
`packages/rust_net` under the workspace root.

### Local Fixture Server

```bash
dart run 'fixture_server/http_fixture_server.dart' --port 8080
```

Current fixture coverage includes:

- `GET /healthz`
- `GET /get`
- `POST|PUT|PATCH /echo`
- `DELETE /delete`
- `HEAD /head`
- `OPTIONS /options`
- `GET /slow?delay_ms=200`
- `GET /status/{code}`
- `GET /redirect/{301|302|303|307|308}?location=/get?source=redirected`

## 中文

`rust_net` 是一个 Flutter HTTP SDK。公开接口保留在 Dart 层，底层 HTTP
执行由 Rust `reqwest` 负责。

`rust_net` 现在是唯一公开的 Dart API 包。平台原生产物正在拆到
`rust_net_native_android`、`rust_net_native_ios` 等载体包中。

### 它解决什么问题

- 在 Rust 层执行 HTTP 请求
- 统一连接复用和传输层行为
- 同时提供直接 Dart 客户端和 `Dio` 适配器
- 暴露重定向后的最终有效 URL

推荐的分层方式是：

- Dart 负责请求组装、适配器和框架集成
- Rust 负责传输执行、重定向、超时和底层网络失败

### 对外能力

- `RustNetClient`
- `RustNetRequest`
- `RustNetResponse`
- `RustNetDioAdapter`

### 与 Dio 集成

如果消费项目已经基于 `Dio`，通常只需要替换 adapter：

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
      defaultHeaders: const <String, String>{'x-sdk': 'rust_net'},
    ),
  );
```

如果你已经有自定义 `HttpExecutor`，也可以直接包装：

```dart
final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter(
    executor: myHttpExecutor,
    closeExecutor: false,
  );
```

当前适配器说明：

- 支持 `GET`、`POST`、`PUT`、`PATCH`、`DELETE`、`HEAD`、`OPTIONS`
- Dart 侧请求体会先缓冲成字节再传给 Rust
- Dio 多种 timeout 会收敛成 `rust_net` 的单次请求 timeout
- 最终跳转 URL 会通过 `RustNetResponse.finalUri` 暴露
- 对 Dio 调用方，还会通过 `x-rust-net-final-uri` 响应头暴露最终 URL
- 取消请求目前仍然是 Dart 边界上的 best-effort

### 代理行为

- 代理选择逻辑在 Rust 层按“每次请求”执行
- 当代理快照变化时，`rust_net` 会重建底层 `reqwest::Client`
- 没有检测到代理时，请求直连
- 优先级：系统代理优先，其次回退环境变量
- 环境变量回退键：`HTTP_PROXY`/`http_proxy`、`HTTPS_PROXY`/`https_proxy`、`ALL_PROXY`/`all_proxy`、`NO_PROXY`/`no_proxy`

平台代理来源：

- Android：通过 `getprop`（`http.proxyHost`、`https.proxyHost`、`socksProxyHost`、`*.nonProxyHosts`）
- iOS/macOS：通过 Apple `SystemConfiguration`
- Windows：读取 `Internet Settings` 注册表
- 其他平台：仅环境变量回退
- 当前仅覆盖手动 HTTP/HTTPS/SOCKS 代理设置，PAC 暂未执行

### 平台说明

当前包已经声明以下 Flutter FFI 插件封装：

- Android
- iOS
- macOS
- Windows

其中 macOS 的打包和运行时解析链路已经在本地验证过；Android、iOS、Windows
的插件封装目录和元数据已经补齐，但仍建议在消费端项目里完成实际打包验证。

Android 构建会优先通过 `package:rust_net_native_android` 使用本地已构建的
`jniLibs`。当某个 ABI 缺失，或设置
`RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` 时，才会在 Gradle 的
`preDebugBuild` / `preReleaseBuild` 阶段回退到源码编译并打包
`librust_net_native.so`。源码回退模式前提是构建机具备：

- 可用的 Rust toolchain
- 已安装的 Android NDK
- 可通过 `rustup` 使用的 Rust Android targets

### 消费项目接入

`pubspec.yaml`：

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^2.0.0
  rust_net_native_android: ^2.0.0 # 按目标平台选择载体包
```

本地开发时准备 macOS 原生库：

```bash
dart run rust_net:prepare_macos_native --configuration debug
```

Android 消费端构建在具备 Rust 和 Android NDK 的前提下，不需要额外手工复制 `.so`。

如果是 sandboxed macOS 应用，需要确保 Runner entitlement 包含
`com.apple.security.network.client`。

### 本地 Path 接入

如果你要直接联调源码仓库，可以让消费项目直接依赖源码包和对应平台 carrier 包：

```yaml
dependencies:
  rust_net:
    path: /absolute/path/to/rust_net/packages/rust_net
  rust_net_native_macos:
    path: /absolute/path/to/rust_net/packages/rust_net_native_macos
```

在 `flutter run` 之前，先准备好对应平台产物：

```bash
dart run /absolute/path/to/rust_net/scripts/workspace_tools.dart bootstrap
/absolute/path/to/rust_net/scripts/build_native_macos.sh debug
```

如果你希望本地依赖结构更接近最终发布形态，可以先物化一个分发工作区：

```bash
dart run /absolute/path/to/rust_net/scripts/prepare_distribution.dart \
  --packages=rust_net,rust_net_native_macos
```

然后在消费项目里依赖生成后的包：

```yaml
dependencies:
  rust_net:
    path: /absolute/path/to/rust_net/.dist/materialized_workspace/packages/rust_net
  rust_net_native_macos:
    path: /absolute/path/to/rust_net/.dist/materialized_workspace/packages/rust_net_native_macos
```

### 仓库结构

- `packages/rust_net/`：Flutter FFI 传输包（当前包）
- `packages/rust_net_native_android|ios|macos|windows|linux/`：平台载体包
- `packages/rust_net/native/rust_net_native/`：基于 `reqwest` 的 Rust `cdylib`
- `fixture_server/`：本地 fixture 处理逻辑

### 本地开发

1. 构建 Rust：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

2. 安装依赖并刷新生成代码：

```bash
dart pub get
dart run ../../scripts/workspace_tools.dart bootstrap
dart run rust_net:prepare_macos_native --configuration debug
dart run ffigen --config ffigen.yaml
dart run build_runner build --delete-conflicting-outputs
```

3. 执行检查：

```bash
cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
dart run ../../scripts/workspace_tools.dart analyze
dart run ../../scripts/workspace_tools.dart test
```

如果要验证 Android 打包链路，建议直接构建消费端 APK，并确认其中包含
`lib/*/librust_net_native.so`。

如果是在 monorepo 本地开发，`rust_net` 包路径是 `packages/rust_net`。

### 本地 Fixture 服务

```bash
dart run 'fixture_server/http_fixture_server.dart' --port 8080
```

当前 fixture 覆盖：

- `GET /healthz`
- `GET /get`
- `POST|PUT|PATCH /echo`
- `DELETE /delete`
- `HEAD /head`
- `OPTIONS /options`
- `GET /slow?delay_ms=200`
- `GET /status/{code}`
- `GET /redirect/{301|302|303|307|308}?location=/get?source=redirected`
