# rust_net

[English](#english) | [中文](#中文)

## English

### Overview

`rust_net` keeps the public HTTP API in Dart while delegating transport
execution to a Rust `reqwest` core. Native libraries are delivered through
`hook/build.dart` + `code_assets`, while the request execute path internally
retains a RINF-style async signal channel between Dart and Rust.

Public API surfaces:

- `RustNetClient`
- `RustNetRequest`
- `RustNetResponse`
- `RustNetDioAdapter`

### Toolchain

- Dart `^3.11.0`
- Flutter `3.41.5` / Dart `3.11.3` recommended for repository development
- Rust toolchain only needed for maintainers validating local native builds

### Install From Git

If your app imports only `package:rust_net/...`, declaring `rust_net` is
enough. Add `rust_net_core` only when your app imports it directly.

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net
  rust_net_core:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net_core
```

### Quick Start

Direct client usage:

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(
    baseUrl: Uri.parse('https://api.example.com/'),
    timeout: const Duration(seconds: 10),
  ),
);

final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);

await client.close();
```

### Dio Integration

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

Adapter notes:

- Supported methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`
- Request bodies are buffered in Dart before being sent to Rust
- Dio timeout fields collapse into one request timeout for `rust_net`
- Final redirect targets are exposed as `RustNetResponse.finalUri`
- Dio callers also receive `x-rust-net-final-uri`
- Cancellation remains best-effort at the Dart boundary

### Native Asset Delivery

Consumer builds do not need to manually copy `.so`, `.dylib`, or `.dll`
files. The package build hook resolves the correct native library for the
target platform at build time.

Current resolution order:

1. explicit manifest override via hook user-defines
2. local maintainer fallback from `native/rust_net_native/target/*`
3. migration fallback from legacy packaged artifacts if present
4. GitHub Release manifest plus platform asset download

### Proxy Behavior

- Proxy selection runs in Rust on every request
- Proxy snapshots trigger `reqwest::Client` rebuild when needed
- Priority is system proxy first, then environment fallback
- Environment fallback keys:
  `HTTP_PROXY`/`http_proxy`,
  `HTTPS_PROXY`/`https_proxy`,
  `ALL_PROXY`/`all_proxy`,
  `NO_PROXY`/`no_proxy`

Platform proxy sources:

- Android: `getprop`
- iOS/macOS: Apple `SystemConfiguration`
- Linux: GNOME `gsettings` with KDE `kreadconfig` fallback
- Windows: `Internet Settings` registry

PAC is not evaluated at the moment.

### Local Maintainer Validation

Build the host Rust dynamic library first:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

Run checks:

```bash
cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
dart run melos analyze
dart run melos test
```

For local end-to-end transport checks, start the fixture server:

```bash
dart run 'fixture_server/http_fixture_server.dart' --port 8080
```

### macOS Note

For sandboxed macOS apps, ensure the Runner entitlements include
`com.apple.security.network.client`.

## 中文

### 概览

`rust_net` 对外保留 Dart 层的 HTTP API，把底层传输执行交给 Rust
`reqwest`。native 库通过 `hook/build.dart` + `code_assets` 分发，真正的请
求执行链路内部仍保留 RINF 风格的 Dart/Rust 异步信号通道。

对外主要 API：

- `RustNetClient`
- `RustNetRequest`
- `RustNetResponse`
- `RustNetDioAdapter`

### 工具链要求

- Dart `^3.11.0`
- 仓库开发推荐使用 Flutter `3.41.5` / Dart `3.11.3`
- 只有维护者做本地 native 验证时才需要 Rust toolchain

### Git 依赖接入

如果业务代码只 import `package:rust_net/...`，只声明 `rust_net` 即可。只有
在直接 import `rust_net_core` 时，才需要额外声明它。

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net
  rust_net_core:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net_core
```

### 快速开始

直接使用客户端：

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(
    baseUrl: Uri.parse('https://api.example.com/'),
    timeout: const Duration(seconds: 10),
  ),
);

final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);

await client.close();
```

### Dio 集成

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

适配器说明：

- 支持 `GET`、`POST`、`PUT`、`PATCH`、`DELETE`、`HEAD`、`OPTIONS`
- Dart 侧会先缓冲请求体，再传给 Rust
- Dio 多个 timeout 会收敛成 `rust_net` 的单次请求 timeout
- 最终跳转地址通过 `RustNetResponse.finalUri` 暴露
- Dio 调用方还会收到 `x-rust-net-final-uri`
- 取消请求目前仍是 Dart 边界上的 best-effort

### Native Asset 分发

消费项目不需要手工复制 `.so`、`.dylib` 或 `.dll`。包内的 build hook 会在
构建时为目标平台解析正确的 native 库。

当前解析顺序：

1. 通过 hook user-defines 显式指定 manifest
2. 维护者本地 `native/rust_net_native/target/*` 回退
3. 若 checkout 中仍有旧产物，则走迁移期 legacy 回退
4. GitHub Release manifest + 平台二进制下载

### 代理行为

- 代理选择逻辑在 Rust 层每次请求时执行
- 代理快照变化时会重建底层 `reqwest::Client`
- 优先级：系统代理优先，其次环境变量回退
- 环境变量回退键：
  `HTTP_PROXY`/`http_proxy`、
  `HTTPS_PROXY`/`https_proxy`、
  `ALL_PROXY`/`all_proxy`、
  `NO_PROXY`/`no_proxy`

平台代理来源：

- Android：`getprop`
- iOS/macOS：Apple `SystemConfiguration`
- Linux：GNOME `gsettings`，KDE `kreadconfig` 回退
- Windows：`Internet Settings` 注册表

当前不处理 PAC。

### 维护者本地验证

先构建宿主机 Rust 动态库：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

再执行检查：

```bash
cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
dart run melos analyze
dart run melos test
```

如果要做本地端到端传输验证，先启动 fixture server：

```bash
dart run 'fixture_server/http_fixture_server.dart' --port 8080
```

### macOS 说明

如果是 sandboxed macOS 应用，需要确保 Runner entitlement 包含
`com.apple.security.network.client`。
