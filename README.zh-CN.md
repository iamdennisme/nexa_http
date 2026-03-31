# nexa_http

[English](./README.md)

## 1. 项目概述

`nexa_http` 是一个以 Rust 传输运行时为核心、以 Dart/Flutter 公开 API 为入口的 HTTP SDK 工作区。

当前项目由这些部分组成：

- `packages/nexa_http`：Flutter 侧公开 Dart 包
- `packages/nexa_http_native_android|ios|macos|windows`：各平台 carrier package
- `native/nexa_http_native_core`：共享 Rust 核心 runtime 和 ABI
- `fixture_server/`：本地真实 HTTP / 图片验证用 fixture server
- `scripts/`：工作区、构建、分发、发布辅助脚本

整体目标很明确：

- Flutter 应用只使用稳定的 Dart API
- 平台打包职责放在各平台 carrier package
- 真实传输执行和平台差异逻辑放在 Rust 原生层

## 2. 实现逻辑

当前的调用链路是：

`Flutter app -> NexaHttpClient -> Call -> internal engine -> worker isolate -> Dart 请求映射 -> FFI bridge -> platform runtime SPI -> nexa_http_native_core -> HTTP transport`

当前分层职责：

- 公开 HTTP API 层：`packages/nexa_http/lib/nexa_http.dart`、`packages/nexa_http/lib/src/api/*`
  只暴露稳定 HTTP 语义：`NexaHttpClient`、`NexaHttpClientBuilder`、`Request`、`RequestBuilder`、`RequestBody`、`Response`、`ResponseBody`、`Headers`、`MediaType`、`Call`、`Callback`、`NexaHttpException`。
- Client / Call facade 层：`packages/nexa_http/lib/src/nexa_http_client.dart`、`packages/nexa_http/lib/src/client/*`
  负责轻量 client 形态和单次请求 `Call` 的执行模型。
- Internal engine 层：`packages/nexa_http/lib/src/internal/engine/*`
  在第一次真实 `execute()` 时惰性初始化共享 worker / native 资源，并复用按配置分组的 native client。
- Internal worker / FFI bridge 层：`packages/nexa_http/lib/src/worker/*`、`packages/nexa_http/lib/src/data/*`
  把公开请求映射到 worker/native 传输协议，并把 native 结果映射回 Dart 响应对象。
- 平台 carrier / SPI 层：`packages/nexa_http_native_*`、`package:nexa_http/nexa_http_platform.dart`
  负责平台注册 runtime hook 和原生二进制打包，不污染根公开 API。
- Native core 层：`native/nexa_http_native_core`
  负责统一 ABI、runtime contract、传输执行，以及 native 侧的平台能力接入。

这意味着：

- Dart 负责 API 形态、调用编排和惰性启动
- Rust 负责真实传输执行
- 所有支持的平台统一走一条 async FFI 请求链
- 平台差异通过 carrier package 和 native 平台模块处理，而不是通过公开 Dart API 处理
- 代理状态由各平台 native runtime 自己维护，`nexa_http_native_core` 只在平台代理 generation 变化时重建 client

## 3. 使用方法

### 正式发布使用

推荐把所有依赖固定到同一个 git tag：

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http
  nexa_http_native_android:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http_native_android
  nexa_http_native_ios:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.1
      path: packages/nexa_http_native_ios
```

只引入你实际需要打包的平台 carrier package。桌面端同理，使用对应的 `nexa_http_native_<platform>` 包。

### 本地 workspace 使用

本地开发可以使用 `path` 依赖：

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

生产环境建议以 `git + tag` 作为一等依赖方式，`path` 模式用于本地联调和调试。

### 客户端调用

根包现在对齐 OkHttp 风格的 HTTP API。

`RequestBuilder` 支持 `GET`、`POST`、`PUT`、`PATCH`、`DELETE`、`HEAD`、`OPTIONS`。

`NexaHttpClient` 是轻量且同步的。worker 启动、native library 加载、native client 创建都在第一次真实 `call.execute()` 时惰性触发。

```dart
import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClientBuilder()
    .baseUrl(Uri.parse('https://api.example.com/'))
    .callTimeout(const Duration(seconds: 10))
    .userAgent('nexa_http/1.0.1')
    .build();

final request = RequestBuilder()
    .url(Uri(path: '/healthz'))
    .get()
    .build();

final response = await client.newCall(request).execute();
final body = await response.body!.string();
```

请求示例：

```dart
final getResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/healthz')).get().build(),
).execute();

final postResponse = await client.newCall(
  RequestBuilder()
      .url(Uri(path: '/users'))
      .post(
        RequestBody.fromString(
          '{"name":"alice"}',
          contentType: MediaType.parse('application/json; charset=utf-8'),
        ),
      )
      .build(),
).execute();

final putResponse = await client.newCall(
  RequestBuilder()
      .url(Uri(path: '/users/1'))
      .put(
        RequestBody.fromString(
          '{"name":"alice-updated"}',
          contentType: MediaType.parse('application/json; charset=utf-8'),
        ),
      )
      .build(),
).execute();

final deleteResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/users/1')).delete().build(),
).execute();

final patchResponse = await client.newCall(
  RequestBuilder()
      .url(Uri(path: '/users/1'))
      .method(
        'PATCH',
        RequestBody.fromString(
          '{"name":"alice-patched"}',
          contentType: MediaType.parse('application/json; charset=utf-8'),
        ),
      )
      .build(),
).execute();

final headResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/healthz')).head().build(),
).execute();

final optionsResponse = await client.newCall(
  RequestBuilder().url(Uri(path: '/users')).method('OPTIONS').build(),
).execute();
```

平台 carrier package 应通过 `package:nexa_http/nexa_http_platform.dart` 注册 runtime。业务代码应只使用 `package:nexa_http/nexa_http.dart`。

### 本地验证命令

```bash
dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
cd packages/nexa_http && fvm dart test
cd packages/nexa_http/example && fvm flutter test
cargo test --workspace
```

真实 HTTP 验证可启动本地 fixture server：

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

桌面端使用 `http://127.0.0.1:8080`，Android 模拟器使用 `http://10.0.2.2:8080`。

## 4. 测试数据

验证时间：`2026-03-29`

### 接口验证

HTTP demo 使用本地 fixture server，对两种外部消费方式做了验证：

- `git + ref: v1.0.1`
- 本地 `path`

结果是：

- 两种模式下，`NexaHttpClient` 的真实 GET 请求都通过
- 两种模式下，外部 Flutter 测试都通过
- 两种模式下，`NexaHttpImageFileService` 的真实图片下载链路也通过

### 图片性能验证

图片性能页面沿用现有实现，没有改动逻辑。

最新 Android 真机 benchmark（`2026-03-29`，设备 `V2405A`，局域网服务 `192.168.1.16:8080`，`24` 张 fixture 图片）：

| Transport | 首屏时间 | 平均延迟 | P95 延迟 | 吞吐 | 请求数 | 失败数 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `defaultHttp` | `329 ms` | `92 ms` | `167 ms` | `14.09 MiB/s` | `24` | `0` |
| `rustNet` | `186 ms` | `55 ms` | `86 ms` | `22.03 MiB/s` | `24` | `0` |

本轮结果中（`rustNet` 对比 `defaultHttp`）：

- 首屏时间：`-43.47%`
- 平均延迟：`-40.22%`
- P95 延迟：`-48.50%`
- 吞吐：`+56.42%`

这组数据是单设备局域网环境的实测结果，不应直接外推为通用 release benchmark。
