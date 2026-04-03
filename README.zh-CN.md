# nexa_http

[English](./README.md)

`nexa_http` 是一个给 Flutter 用的 HTTP SDK：公开 API 走 Dart，底层真实传输走 Rust。

如果你只是想把它接进应用，心智模型其实很小：

- 依赖只声明 `nexa_http`
- 代码里只 import `package:nexa_http/nexa_http.dart`
- 请求和响应都按公开 HTTP API 使用
- 平台 runtime 注册、原生产物解析、平台接入这些事，都由工作区内部处理

也就是说，这个仓库虽然内部结构不少，但绝大多数都不是业务代码需要直接关心的东西。

## 应用接入

正常应用只应该声明 `nexa_http` 这一个包。

### Git / SSH 依赖

```yaml
dependencies:
  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.1
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

### 应用代码不需要直接处理什么

正常业务代码不应该去关心这些：

- platform carrier packages
- runtime 注册
- native library 加载
- release manifest 查找
- release asset 下载规则

这些都属于包边界之后的内部实现。

## 运行 Demo

demo 应用在 [`packages/nexa_http/example`](./packages/nexa_http/example)。

它现在有两个页面：

- **HTTP Playground**：用公开 API 发真实请求，并查看响应
- **Benchmark**：在同一套并发请求计划下，对比 `nexa_http` 和 Dart `HttpClient`

### 1. 先启动本地 fixture server

在仓库根目录执行：

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

如果你本机的 Dart 版本已经和仓库要求一致，`dart run` 也可以。但对这个仓库来说，默认还是更推荐 `fvm`。

### 2. 再运行 example

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

其他支持的平台也用同一个 example 工程，不需要改源码：

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d windows
fvm flutter run -d android
fvm flutter run -d ios
```

### 本地常用 base URL

- macOS / Windows 主机：`http://127.0.0.1:8080`
- Android 模拟器：`http://10.0.2.2:8080`
- Android 真机配合 `adb reverse tcp:8080 tcp:8080`：`http://127.0.0.1:8080`
- iOS 模拟器同主机：`http://127.0.0.1:8080`

### 平台说明

- macOS / Windows：先在同一台机器上启动 fixture server，再执行 `flutter run`
- Android 模拟器：保持默认 `10.0.2.2`
- Android 真机：如果 fixture server 跑在宿主机上，先执行 `adb reverse tcp:8080 tcp:8080`
- iOS 模拟器：默认回环地址可直接使用
- 真机：通过 `--dart-define=NEXA_HTTP_EXAMPLE_BASE_URL=...` 传入可访问的宿主地址

## Benchmark

benchmark 页面会顺序执行 `nexa_http` 和 Dart `HttpClient` 两组测试，避免两边互相抢带宽、连接和系统资源。

### 支持的场景

- `bytes`：请求 `/bytes?size=...&seed=...`
- `image`：请求 `/image?id=...`

### 可调参数

- `baseUrl`
- `scenario`
- `concurrency`
- `totalRequests`
- `payloadSize`
- `warmupRequests`
- `timeout`

### 当前展示的指标

每个 transport 都会展示：

- total duration
- throughput（`MiB/s`）
- requests per second
- first-request latency
- post-warmup average latency
- P50 latency
- P95 latency
- P99 latency
- max latency
- success count
- failure count
- failure breakdown
- bytes received

example 也支持通过 `--dart-define` 注入 benchmark 默认值，例如：

- `NEXA_HTTP_EXAMPLE_BASE_URL`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_SCENARIO`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_CONCURRENCY`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_TOTAL_REQUESTS`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_PAYLOAD_SIZE`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_WARMUP_REQUESTS`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_TIMEOUT_MS`
- `NEXA_HTTP_EXAMPLE_AUTO_RUN_BENCHMARK`
- `NEXA_HTTP_EXAMPLE_EXIT_AFTER_BENCHMARK`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_OUTPUT_PATH`

具体启动示例可以看：

- [`packages/nexa_http/example/README.md`](./packages/nexa_http/example/README.md)

## 从 Release Tag 消费

这个仓库把整个工作区视为一条统一的 release train。

也就是说：

- `nexa_http`
- `nexa_http_runtime`
- `nexa_http_distribution`
- 所有 platform carrier packages

应该始终一起移动，保持同一个语义化版本。

release asset 也是按同一个仓库 tag，由 GitHub Actions 发布。

### Tag 规则

- release-train 包版本必须保持一致
- 每次工作区发布只使用一个统一 tag
- git 消费和 release asset 发布都绑定同一个 tag

发布前，仓库会用下面的命令检查 tag 和版本是否一致：

```bash
fvm dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z
```

为了证明某个 tag 对外部用户真的可消费，仓库还提供：

```bash
fvm dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z
```

这个命令会：

- 在仓库外创建一个临时 Flutter app
- 用 git+ssh + tag 方式解析 `packages/nexa_http`
- 执行最小宿主构建校验
- 成功后删除这个临时 app

如果要跑完整的受治理 tag 验证流程，可以用：

```bash
./scripts/tag_release_validation.sh run --tag vX.Y.Z --remote origin --branch develop
```

这个脚本负责：

- push 分支
- 按需重建受治理 tag
- 发布 tag
- 等待 tag 触发的 release workflow 结束

## 维护者工作流

这个仓库把调试、打包、发布和外部消费流程都视为 governed operating contracts。

如果要改这些流程，先更新对应的 OpenSpec specs，再改实现。

### 工作区级命令

```bash
fvm dart pub get
fvm dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-release-consumer
fvm dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z
```

### 聚焦包级验证

```bash
cd packages/nexa_http
fvm dart test

cd packages/nexa_http/example
fvm flutter test
fvm flutter analyze
```

### Release workflow 入口

tag 触发的 release workflow 在：

- [`.github/workflows/release-native-assets.yml`](./.github/workflows/release-native-assets.yml)

更完整的流程约定在：

- [`docs/runtime-release-contract.md`](./docs/runtime-release-contract.md)

## 工作区结构

如果你只是要接入 SDK，到这里其实就可以停了。下面这部分主要是给仓库维护者看的。

### Dart packages

- `packages/nexa_http`：给应用使用的公开 HTTP API
- `packages/nexa_http_runtime`：runtime SPI、loader 行为、host platform 发现
- `packages/nexa_http_distribution`：原生产物解析和 release manifest 逻辑
- `packages/nexa_http_native_android|ios|macos|windows`：各平台 carrier package，负责 runtime 注册和打包

### Rust 代码

共享 Rust core 在：

- `native/nexa_http_native_core`

各平台自己的 native crate 在对应 carrier package 下面，例如：

- `packages/nexa_http_native_macos/native/...`
- `packages/nexa_http_native_ios/native/...`
- `packages/nexa_http_native_android/native/...`
- `packages/nexa_http_native_windows/native/...`

### 本地 fixture 和脚本

- `fixture_server/`：example 和测试使用的本地 HTTP fixture server
- `scripts/`：工作区构建、验证、发布和 tag validation 相关脚本

## 设计意图

这个仓库的拆分不是为了“看起来分层很漂亮”，而是为了让公开 SDK 继续保持简单：

- 应用代码只处理 HTTP 语义
- 平台 package 吞掉 runtime 注册细节
- transport 启动保持惰性和内部化
- release-consumer 行为保持明确
- release asset 由仓库级 workflow 管理，而不是靠临时本地操作

也正因为这样，虽然仓库内部有不少 native 和 release machinery，公开 SDK 的使用方式仍然可以保持很窄、很稳定。
