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

`Flutter app -> NexaHttpClient -> Dart 请求映射 -> FFI bridge -> 平台 native runtime -> nexa_http_native_core -> HTTP transport`

当前分层职责：

- 公开 API 层：`packages/nexa_http`
  对外暴露 `NexaHttpClient`、请求/响应模型、配置、异常和图片文件服务。
- 平台 carrier 层：`packages/nexa_http_native_*`
  为各平台注册 native runtime，并交付最终原生二进制。
- Native core 层：`native/nexa_http_native_core`
  负责统一 ABI、runtime contract、传输执行，以及 native 侧的平台能力接入。

这意味着：

- Dart 负责 API 形态和调用编排
- Rust 负责真实传输执行
- 所有支持的平台现在统一走一条 async FFI 请求链
- 平台差异通过 native 平台模块处理，而不是通过公开 Dart API 处理
- 代理状态由各平台 native runtime 自己维护，`nexa_http_native_core` 只在平台代理 generation 变化时重建 client

## 3. 使用方法

### 正式发布使用

推荐把所有依赖固定到同一个 git tag：

```yaml
dependencies:
  nexa_http:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http
  nexa_http_native_android:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
      path: packages/nexa_http_native_android
  nexa_http_native_ios:
    git:
      url: https://github.com/iamdennisme/nexa_http.git
      ref: v1.0.0
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

dependency_overrides:
  nexa_http:
    path: ../nexa_http/packages/nexa_http
```

当前本地 `path` 模式仍需要给 `nexa_http` 增加 `dependency_overrides`。

### 客户端调用

`NexaHttpRequest` 当前提供 4 个请求 helper：`get`、`post`、`put`、`delete`。

```dart
import 'dart:convert';

import 'package:nexa_http/nexa_http.dart';

final client = NexaHttpClient(
  config: NexaHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com/'),
    timeout: const Duration(seconds: 10),
  ),
);

final response = await client.execute(
  NexaHttpRequest.get(uri: Uri(path: '/healthz')),
);

await client.close();
```

请求示例：

```dart
final getResponse = await client.execute(
  NexaHttpRequest.get(
    uri: Uri(path: '/healthz'),
  ),
);

final postResponse = await client.execute(
  NexaHttpRequest.post(
    uri: Uri(path: '/users'),
    headers: {'content-type': 'application/json'},
    bodyBytes: utf8.encode('{"name":"alice"}'),
  ),
);

final putResponse = await client.execute(
  NexaHttpRequest.put(
    uri: Uri(path: '/users/1'),
    headers: {'content-type': 'application/json'},
    bodyBytes: utf8.encode('{"name":"alice-updated"}'),
  ),
);

final deleteResponse = await client.execute(
  NexaHttpRequest.delete(
    uri: Uri(path: '/users/1'),
  ),
);
```

### 本地验证命令

```bash
dart pub get
dart run scripts/workspace_tools.dart bootstrap
fvm dart run scripts/workspace_tools.dart analyze
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

- `git + ref: v1.0.0`
- 本地 `path`

结果是：

- 两种模式下，`NexaHttpClient` 的真实 GET 请求都通过
- 两种模式下，外部 Flutter 测试都通过
- 两种模式下，`NexaHttpImageFileService` 的真实图片下载链路也通过

### 图片性能验证

图片性能页面沿用现有实现，没有改动逻辑。下面的数据来自外部 `git` sample，在 macOS debug 模式下，对 `24` 张 fixture 图片进行采样。

| Transport | 首屏时间 | 平均延迟 | P95 延迟 | 吞吐 | 请求数 | 失败数 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `defaultHttp` | `802 ms` | `39 ms` | `61 ms` | `35.58 MiB/s` | `24` | `0` |
| `rustNet` | `313 ms` | `9 ms` | `22 ms` | `75.40 MiB/s` | `24` | `0` |

benchmark 命令模板：

```bash
cd /path/to/your/external_git_sample
env PUB_HOSTED_URL=https://pub.dev \
  FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
  fvm flutter run -d macos \
  --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_SCENARIO=image \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_TRANSPORT=nexa_http \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_IMAGE_COUNT=24
```

这组数据是本地 debug 测量结果，不应直接视为 release 构建 benchmark。
