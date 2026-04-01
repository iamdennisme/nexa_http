# nexa_http

[English](./README.md)

`nexa_http` 是一个 Flutter HTTP 工作区：公开 API 走 Dart，真实传输走 Rust。

## 工作区结构

仓库现在按职责拆成几块：

- `packages/nexa_http`：给 Flutter 应用使用的公开 Dart 包
- `packages/nexa_http_native_android|ios|macos|windows`：各平台 carrier
  package，负责原生 runtime 的注册和打包
- `packages/nexa_http/native/rust_net_native`：Rust 传输实现
- `fixture_server/`：example 和测试使用的本地 HTTP fixture server
- `scripts/`：工作区构建和验证脚本

对外心智模型刻意保持简单：

- 业务代码只接触 HTTP 语义
- carrier package 负责平台接入
- transport 初始化是内部惰性的

## 公开 API

根入口是
[`package:nexa_http/nexa_http.dart`](./packages/nexa_http/lib/nexa_http.dart)。

当前公开导出的是：

- `NexaHttpClient`
- `NexaHttpClientBuilder`
- `Request`
- `RequestBuilder`
- `RequestBody`
- `Response`
- `ResponseBody`
- `Headers`
- `MediaType`
- `Call`
- `Callback`
- `NexaHttpException`

典型调用方式：

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

`NexaHttpClient` 本身是轻量、同步的。native 加载、worker 启动、底层
transport 获取，都在第一次真实 `call.execute()` 时惰性发生。

## 平台包

业务代码应该始终使用 `package:nexa_http/nexa_http.dart`。

carrier package 会在内部通过
`package:nexa_http_runtime/nexa_http_runtime.dart` 注册 runtime，build hook
通过 `package:nexa_http_distribution/nexa_http_distribution.dart` 解析原生产物。
这两个入口都是给平台接入用的，不是给业务方直接用的。

## 包边界

现在工作区里的 Dart 侧职责明确分成三类：

- `nexa_http`：面向应用的 HTTP API 和 transport bridge
- `nexa_http_runtime`：runtime SPI、loader、host platform 发现
- `nexa_http_distribution`：build hook 和 release tooling 使用的原生产物解析

这个拆分是刻意设计的。`nexa_http` 不再反向暴露 runtime 或 distribution
入口。

## 版本与发布策略

这个工作区应被视为一条统一的发布线。

- `nexa_http`
- `nexa_http_runtime`
- `nexa_http_distribution`
- 所有 carrier package

这些包都应保持同一个语义化版本。

如果改动涉及 runtime loading、manifest 格式、carrier package 集成，应该整组
一起升级，而不是让版本漂移。

native asset 的 GitHub workflow 会按仓库 tag 发布产物，所以每次工作区发布都应
使用一个统一 tag。

工作区内的依赖示例：

```yaml
dependencies:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
  nexa_http_native_macos:
    path: ../nexa_http/packages/nexa_http_native_macos
```

如果从 Git 消费，而不是用 `path`，要保证 `nexa_http` 和对应 carrier
package 固定到同一个 ref。

## Example App

demo 应用在
[`packages/nexa_http/example`](./packages/nexa_http/example)。

当前只有两个页面：

- `HTTP Playground`：用公开 API 发真实请求，并查看请求和响应内容
- `Benchmark`：对比 `nexa_http` 和 Dart `HttpClient` 的并发表现，支持
  `bytes` 和 `image` 两种场景

先启动 fixture server：

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

再运行 example：

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

本地常用 base URL：

- macOS / Windows 主机：`http://127.0.0.1:8080`
- Android 模拟器：`http://10.0.2.2:8080`

Benchmark 页面保留了少量可调参数：

- `baseUrl`
- `scenario`：`bytes` 或 `image`
- `concurrency`
- `totalRequests`
- `payloadSize`
- `warmupRequests`
- `timeout`

## 验证命令

工作区级命令：

```bash
dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
```

聚焦包级命令：

```bash
cd packages/nexa_http
fvm dart test

cd packages/nexa_http/example
fvm flutter test
fvm flutter analyze
```
