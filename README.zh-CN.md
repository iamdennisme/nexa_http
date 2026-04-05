# nexa_http

[English](./README.md)

`nexa_http` 是一个面向 Flutter 的 HTTP SDK：上层提供接近 OkHttp 风格的 Dart API，底层传输由 Rust 驱动。

如果你想保留 Dart 侧顺手的请求写法，同时把传输层放到 native 里，这个项目就是为这种场景准备的。

## 为什么用它

- 应用侧 API 尽量保持简单
- 传输层由 Rust 驱动
- Android / iOS / macOS / Windows 都有明确的 carrier 包
- 仓库里有一个可直接运行的 demo，可以把 Flutter → FFI → Rust 这条链路跑一遍

## 支持平台

- Android
- iOS
- macOS
- Windows

## 安装

普通应用通常只需要两类依赖：

1. `nexa_http`
2. 你目标平台对应的 carrier package

### Git 依赖

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: vX.Y.Z
      path: packages/nexa_http
  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: vX.Y.Z
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
```

## Demo

官方 demo 在 [`app/demo`](./app/demo)。

先在仓库根目录启动 fixture server：

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

然后在 macOS 上运行 demo：

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

- `packages/nexa_http` —— 公开 Dart SDK
- `packages/nexa_http_native_internal` —— 内部 runtime/loading 层
- `packages/nexa_http_native_android` —— Android carrier
- `packages/nexa_http_native_ios` —— iOS carrier
- `packages/nexa_http_native_macos` —— macOS carrier
- `packages/nexa_http_native_windows` —— Windows carrier
- `native/nexa_http_native_core` —— 共享 Rust transport core

## 开发与验证

如果你在维护这个仓库，最常用的本地检查是：

```bash
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

更完整的验证流程在 [`docs/verification-playbook.md`](./docs/verification-playbook.md)。

## License

[LICENSE](./LICENSE)
