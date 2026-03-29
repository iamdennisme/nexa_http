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

典型依赖方式：

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
