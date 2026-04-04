# nexa_http

[English](./README.md)

`nexa_http` 是一个给 Flutter 用的 HTTP SDK：公开 API 走 Dart，底层真实传输走 Rust。

它希望把应用侧的使用方式尽量收窄：

- 依赖只声明 `nexa_http`
- 代码里只 import `package:nexa_http/nexa_http.dart`
- 请求和响应都按公开 HTTP API 使用
- 平台注册与固定装载契约由 SDK 内部处理

## 安装

正常应用只应该声明 `nexa_http` 这一个包。

### Git / SSH 依赖

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: vX.Y.Z
      path: packages/nexa_http
```

### 本地 path 依赖

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
```

公开入口是 [`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart)。

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .callTimeout(const Duration(seconds: 10))
    .userAgent('example-app/1.0.0')
    .build();

final request = RequestBuilder()
    .url(Uri.parse('https://api.example.com/healthz'))
    .header('accept', 'application/json')
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body?.string();
```

正常业务代码不需要直接处理 platform carrier packages、runtime strategy 注册、native library 加载，或 release asset 查找这些事情。生产环境里的动态库装载只走固定契约，不依赖运行时路径 override。

## 试一下 Demo

仓库里的 demo 在 [`packages/nexa_http/example`](./packages/nexa_http/example)。

先在仓库根目录启动 fixture server：

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

然后运行 example：

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

demo 目前包含：

- `HTTP Playground`：用公开 API 发真实请求
- `Benchmark`：对比 `nexa_http` 和 Dart `HttpClient`

更完整的平台说明、benchmark 参数和环境变量说明请看：

- [`packages/nexa_http/example/README.md`](./packages/nexa_http/example/README.md)

## 说明

- 仓库本地开发和 demo 运行使用当前 workspace 源码。
- 外部使用方只通过 `nexa_http` 接入。
- native 启动对 SDK 使用者保持惰性和内部化，且 runtime strategy 注册是生产环境唯一的装载路径。

## 更多文档

- 包说明：[`packages/nexa_http/README.md`](./packages/nexa_http/README.md)
- Demo 说明：[`packages/nexa_http/example/README.md`](./packages/nexa_http/example/README.md)

## 仓库结构

如果你只是要接入 SDK，到这里其实就可以停了。

- `packages/nexa_http` — 公开 SDK
- `packages/nexa_http_native_runtime_internal` — 内部 native runtime / loading 层，由 `nexa_http` 使用
- `packages/nexa_http_native_android|ios|macos|windows` — 负责产物生成的各平台 carrier packages
- `native/nexa_http_native_core` — 共享 Rust core
