# nexa_http

[English](./README.md)

`nexa_http` 是一个给 Flutter 用的 HTTP SDK：上层是接近 OkHttp 风格的 Dart API，底层传输由 Rust 驱动。

这个仓库想解决的事情很直接：

- 业务代码只面对一个 public SDK
- 平台相关的 native 加载细节藏在 SDK 后面
- 公共传输逻辑收敛到 Rust
- 各平台 carrier 负责打包对应平台产物

## 这个项目解决什么问题

如果你希望：

- 在 Flutter 侧保留顺手的 Dart 请求构建体验
- 在传输层使用 Rust
- 不把 native 启动、动态库加载、平台差异暴露给业务代码

那这个仓库就是围绕这件事构建的。

它提供：

- 一个尽量小的公开 Dart API
- 惰性的 native 启动流程
- 一个共享 Rust native core
- Android / iOS / macOS / Windows 的平台 carrier

## 安装

应用侧真正需要关心的只有两类产物：

1. `nexa_http` —— 必选，公开 SDK
2. `nexa_http_native_<platform>` —— 按你支持的平台选择对应 carrier

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

## 分层

当前仓库按 5 层组织：

1. `app/demo` —— 官方 demo
2. `packages/nexa_http` —— public SDK
3. `packages/nexa_http_native_internal` —— internal native runtime / loading 层
4. `packages/nexa_http_native_<platform>` —— 各平台 carrier
5. `native/nexa_http_native_core` —— 共享 Rust core

### 外部项目真正会接触什么

对接入方来说，只需要理解两类产物：

- `nexa_http`
- 你要支持的平台对应的 carrier package

其他内容都属于内部实现细节。

## Demo

官方 demo 在 [`app/demo`](./app/demo)。

先在仓库根目录启动 fixture server：

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

然后运行 demo：

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

demo 目前包含：

- `HTTP Playground`
- `Benchmark`

更完整的说明见 [`app/demo/README.md`](./app/demo/README.md)。

## 开发与验证

常用校验命令：

```bash
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

## 仓库结构

- `app/demo` —— demo 应用
- `packages/nexa_http` —— 公开 SDK
- `packages/nexa_http_native_internal` —— 内部 native runtime/loading 层
- `packages/nexa_http_native_android` —— Android carrier
- `packages/nexa_http_native_ios` —— iOS carrier
- `packages/nexa_http_native_macos` —— macOS carrier
- `packages/nexa_http_native_windows` —— Windows carrier
- `native/nexa_http_native_core` —— 共享 Rust core
- `fixture_server` —— 本地 HTTP fixture server

## 给开发者的约束

这个仓库有几条核心边界：

- `nexa_http` 是唯一 public Dart API surface
- app 代码不应该感知 internal runtime 细节
- carrier 只负责平台注册、装配和产物打包
- 共享传输逻辑应该收敛在 `nexa_http_native_core`

## License

[LICENSE](./LICENSE)
