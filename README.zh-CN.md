# nexa_http

[English](./README.md)

`nexa_http` 是一个面向 Flutter 的 HTTP SDK：上层提供接近 OkHttp 风格的 Dart API，底层传输由 Rust 驱动。

如果你想保留 Dart 侧顺手的请求写法，同时把传输层放到 native 里，这个项目就是为这种场景准备的。

## 为什么用它

- 应用侧 API 尽量保持简单
- 传输层由 Rust 驱动
- Android / iOS / macOS / Windows 都有显式 platform carrier 包
- 仓库里有一个可直接运行的 demo，可以把 Flutter → FFI → Rust 这条链路跑一遍

## 支持平台

- Android
- iOS
- macOS
- Windows

## 架构

这个 monorepo 只有两个主层：

- **Flutter SDK 层**：`packages/nexa_http`、`packages/nexa_http_native_internal`、各平台 carrier package、build hook 和验证工具。
- **原生 native 层**：共享 Rust core、各平台 FFI crate 和 native build scripts。

Platform carrier、build hook、release asset 和 clean-host verification 都是连接这两层的机制，不是宿主 App 直接使用的独立 API。

## 安装

普通应用的 runtime 代码只 import `package:nexa_http/nexa_http.dart`，
但 `pubspec.yaml` 需要同时声明 `nexa_http` 和目标平台对应的 carrier package。

### Git 依赖

必须使用真实已发布 release tag。下面示例使用 `v1.0.2`。

```yaml
dependencies:
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

### 本地 path 依赖

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

## 快速开始

公开入口是 [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart)。

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('my-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/healthz'))
    .header('accept', 'application/json')
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
await client.close();
```

`Call` 和 `ResponseBody` 都是一次性的。重复同一个 `Request` 时重新调用
`client.newCall(request)`；每个响应体只调用一次 `bytes()` 或 `string()`。

## Demo

官方 demo 在 [`app/demo`](./app/demo)。

先在仓库根目录启动 fixture server：

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

如果你在维护这个仓库，先准备本地 debug artifact，再运行 workspace demo：

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_ios.sh debug
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

demo 里有两部分：

- `HTTP Playground`
- `Benchmark`

更完整的运行说明见 [`app/demo/README.md`](./app/demo/README.md)。

## 包结构

Flutter SDK 层：

- `packages/nexa_http` —— 公开 Dart SDK
- `packages/nexa_http_native_internal` —— 内部 runtime/loading 与 artifact materialization helper
- `packages/nexa_http_native_android` —— Android carrier
- `packages/nexa_http_native_ios` —— iOS carrier
- `packages/nexa_http_native_macos` —— macOS carrier
- `packages/nexa_http_native_windows` —— Windows carrier

原生 native 层：

- `native/nexa_http_native_core` —— 共享 Rust transport core
- `packages/nexa_http_native_*/native/*_ffi` —— 平台 FFI crate

发布时 GitHub Release 会包含 native 下载产物。Carrier build hook 会下载、校验这些产物，并把对应平台动态库物化到 carrier/App 的构建布局中。

## 开发与验证

如果你在维护这个仓库，最常用的本地检查是：

```bash
fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux
fvm dart run scripts/workspace_tools.dart matrix --suite verify-integration
fvm dart run scripts/workspace_tools.dart check rust-format --execution static-linux
```

`verify-integration` 与 `verify-release-candidate` 必须显式传入 Catalog matrix
给出的 execution、fixture URL 和 device。原子 `check` 只用于诊断；CI 与发布门禁
只能使用完整 suite。

更完整的验证流程在 [`docs/verification-playbook.md`](./docs/verification-playbook.md)。

## License

[LICENSE](./LICENSE)
