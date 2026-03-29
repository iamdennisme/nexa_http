# nexa_http workspace

[English](./README.md)

`nexa_http` 是一个 Flutter HTTP SDK 工作区，核心结构是：

- 纯 Dart 的公开 API 包
- 共享 Rust 原生核心
- 每个平台一个 Flutter 包 + Rust 实现 crate

公开 API 保留在 Dart 层，底层传输执行保留在 Rust 层。

## 工作区结构

- `packages/nexa_http`：公开 Dart API、请求模型、FFI bindings
- `packages/nexa_http_native_android|ios|macos|linux|windows`：平台载体包、build hook、平台 Rust runtime
- `native/nexa_http_native_core`：共享 Rust 核心 runtime 和统一 ABI
- `fixture_server/`：本地 HTTP fixture server 与代理验证工具
- `scripts/`：原生产物构建、分发和工作区辅助脚本

当前受 git 跟踪、也是实际生效的工作区包就是上面的 `nexa_http*` 系列。如果你本地磁盘里还残留 `packages/rust_net*` 目录，应把它们视为早期改名后的遗留产物，而不是当前工作区的一部分。

## 架构说明

- `nexa_http` 现在是纯 Dart 包，不再负责构建、下载或自行探测原生产物。
- `nexa_http_native_core` 是纯 Rust 核心 crate，负责 runtime、代理策略、DTO 和统一 C ABI。
- 每个 `nexa_http_native_<platform>` 包都负责：
  - 该平台的 Flutter 注册
  - 该平台的 build hook
  - 该平台的 Rust crate
  - 最终原生产物的打包与提供

消费方需要显式依赖自己要打包的平台包。

## 在其他项目中使用

正式发布时，推荐使用固定到 release tag 的 git 依赖：

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

如果你要切到别的固定发布版本，把所有包的 `ref:` 一起改掉。

说明：

- 所有包都应固定到同一个 `ref`
- 只添加你实际会打包的平台 carrier package
- 桌面端同理，使用同仓库里的对应 `nexa_http_native_<platform>` 包
- 这是目前已经验证过的正式消费路径。carrier package 会通过同一 tag 对应的 GitHub Release manifest 拉取预编译原生产物。

本地 workspace 开发时，也可以使用 `path` 依赖：

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

`path` 模式说明：

- 当前本地 `path` 消费仍需要给 `nexa_http` 加一个 `dependency_overrides`，因为各 carrier package 自己的 `pubspec.yaml` 里还是把 `nexa_http` 固定成 git 依赖。
- 这个 override 只针对本地开发；正式发布路径仍然推荐 `git + ref`。

直接使用客户端：

```dart
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

## 原生产物交付模式

推荐优先级：

1. 发布包 + 预编译原生产物
2. Git 依赖 + 预编译原生产物
3. 本地 workspace path 开发
4. 本地 native override 调试

当前已经验证通过的正式路径是第 2 种。

当前平台 hook 支持这些 override：

- `NEXA_HTTP_NATIVE_<PLATFORM>_LIB_PATH`
- `NEXA_HTTP_NATIVE_<PLATFORM>_SOURCE_DIR`
- `NEXA_HTTP_NATIVE_MANIFEST_PATH`
- `NEXA_HTTP_NATIVE_RELEASE_BASE_URL`

说明：

- `LIB_PATH`：直接指向原生二进制文件
- `SOURCE_DIR`：指向平台 Rust crate 根目录，并要求它的 `target/` 或 repo-root `target/` 下已经有构建输出
- `MANIFEST_PATH` / `RELEASE_BASE_URL`：用于基于 manifest 的预编译产物下载

## 本地开发

初始化 Dart / Flutter 依赖：

```bash
dart pub get
dart run scripts/workspace_tools.dart bootstrap
```

运行 root Dart 测试：

```bash
fvm dart test test
```

运行包测试：

```bash
cd packages/nexa_http && fvm dart test
cd packages/nexa_http/example && fvm flutter test
```

运行 Rust workspace 测试：

```bash
cargo test --workspace
```

## 本地构建原生产物

构建全部平台：

```bash
./scripts/build_native_all.sh debug
```

或者单独构建：

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_linux.sh debug
./scripts/build_native_windows.sh debug
./scripts/build_native_ios.sh debug
./scripts/build_native_android.sh debug
```

产物会被放到各平台包目录中：

- Android：`packages/nexa_http_native_android/android/src/main/jniLibs/*/libnexa_http_native.so`
- iOS：`packages/nexa_http_native_ios/ios/Frameworks/*.dylib`
- Linux：`packages/nexa_http_native_linux/linux/Libraries/libnexa_http_native.so`
- macOS：`packages/nexa_http_native_macos/macos/Libraries/libnexa_http_native.dylib`
- Windows：`packages/nexa_http_native_windows/windows/Libraries/nexa_http_native.dll`

这些文件属于构建输出，不应提交。

## 分发辅助脚本

准备接近发布形态的本地 workspace：

```bash
dart run scripts/prepare_distribution.dart \
  --packages=nexa_http,nexa_http_native_macos
```

只物化、不重建：

```bash
dart run scripts/materialize_distribution.dart \
  --packages=nexa_http,nexa_http_native_macos
```

生成 native asset manifest：

```bash
dart run scripts/generate_native_asset_manifest.dart \
  --version 1.0.0
```

## Fixture server

本地 HTTP / 代理验证：

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

默认只绑定到 `127.0.0.1`。

不同运行目标应使用不同 base URL：

- 桌面宿主机本地运行：`http://127.0.0.1:8080`
- Android 模拟器：`http://10.0.2.2:8080`
- Android 真机通过 `adb reverse`：先执行 `adb reverse tcp:8080 tcp:8080`，然后使用 `http://127.0.0.1:8080`
- 真机走局域网：用 `--host 0.0.0.0` 启动 fixture server，并改成你电脑的局域网 IP，例如 `http://192.168.1.16:8080`

## Demo 验证报告

本次验证时间：`2026-03-29`

验证环境：

- 固定到 `v1.0.0` 的外部 `git` sample
- 指向本地 workspace 的外部 `path` sample
- macOS 桌面端
- 本地 fixture server：`http://127.0.0.1:8080`

HTTP demo 验证结果：

- `git` sample：通过 `NexaHttpClient` 完成真实 fixture GET 请求验证
- `path` sample：通过 `NexaHttpClient` 完成真实 fixture GET 请求验证
- 两个 sample 的外部 Flutter 测试都通过，包含新增的 host smoke test

图片性能 demo 验证结果：

- 直接复用了现有图片性能页面实现，没有改动页面逻辑
- 两个 sample 的图片性能相关 widget / logic 测试均通过
- 两个 sample 都通过了 `NexaHttpImageFileService` 的真实图片下载链路验证
- 下面这组 benchmark 数据来自外部 `git` sample，在 macOS debug 模式下，用 `image` autorun 场景对 `24` 张 fixture 图片进行采样

观测到的 benchmark 结果：

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

说明：

- 这组数据来自本地 debug 构建，不应直接当作正式 release benchmark。
- 在这次验证里，`rustNet` 在首屏时间、平均延迟、P95 延迟和吞吐上都优于默认图片传输链路。
- 本地 `path` 消费也已经验证通过，但当前仍需要给 `nexa_http` 增加一个 `dependency_overrides`。
- 本次使用的临时外部验证 sample 是一次性产物，没有保留在仓库中。
