# rust_net workspace

[English](./README.md)


### 项目介绍

`rust_net` 是一个 Flutter HTTP SDK 工作区：对业务开放的 API 保持在 Dart
层，底层传输执行交给 Rust `reqwest` 内核。

这个仓库主要用于：

- 维护统一的领域契约（`rust_net_core`）
- 实现 Flutter FFI 传输层（`rust_net`）
- 管理 Rust 原生运行时与多平台打包
- 提供本地 fixture/proxy 集成测试工具

### 仓库内容

- `packages/rust_net_core`：领域实体、异常定义、仓储接口契约
- `packages/rust_net`：Flutter 包、FFI 桥接实现、Dio 适配器
- `packages/rust_net/native/rust_net_native`：基于 `reqwest` 的 Rust `cdylib`
- `fixture_server/`：本地 HTTP fixture 服务与代理冒烟测试工具
- `scripts/`：多平台原生库构建脚本

### 包详情

- `packages/rust_net_core`：纯 Dart 领域契约与模型（`RustNetRequest`、`RustNetResponse`、`RustNetException`、`HttpExecutor` 等）。
- `packages/rust_net`：基于 Rust `reqwest` 的 Flutter FFI 传输实现，并提供 `Dio` 适配器集成。

### 本地开发

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

### 编译原生库

当 Rust 原生代码变更后，可重新编译并提交预编译产物：

```bash
./scripts/build_native_all.sh release
git add packages/rust_net/android/src/main/jniLibs \
        packages/rust_net/ios/Frameworks \
        packages/rust_net/macos/Libraries \
        packages/rust_net/linux/Libraries \
        packages/rust_net/windows/Libraries
```

也可以按平台单独编译：

```bash
./scripts/build_native_macos.sh
./scripts/build_native_android.sh
./scripts/build_native_ios.sh
./scripts/build_native_linux.sh
./scripts/build_native_windows.sh
```

Android 说明：

- 默认优先使用仓库内预编译 `jniLibs`。
- 仅在 ABI 库缺失，或设置 `RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` 时，回退到源码编译。
- 源码回退模式需要构建机具备 Rust toolchain 和 Android NDK。

### Flutter 使用方式

`pubspec.yaml`：

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^0.1.0
  # 可选
  rust_net_core: ^0.1.0
```

作为 Dio adapter 使用：

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

直接使用核心客户端：

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(baseUrl: Uri.parse('https://api.example.com/')),
);
final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);
await client.close();
```

### 代理行为

- 代理选择逻辑在 Rust 层按“每次请求”执行。
- 当代理快照变化时，`rust_net` 会重建底层 `reqwest::Client`。
- 没有检测到代理时，请求直连。
- 优先级：系统代理优先，其次回退环境变量。
- 环境变量回退键：`HTTP_PROXY`/`http_proxy`、`HTTPS_PROXY`/`https_proxy`、`ALL_PROXY`/`all_proxy`、`NO_PROXY`/`no_proxy`。

平台代理来源：

- Android：通过 `getprop`（`http.proxyHost`、`https.proxyHost`、`socksProxyHost`、`*.nonProxyHosts`）
- iOS/macOS：通过 Apple `SystemConfiguration`
- Linux：优先读取 GNOME `gsettings`，并回退 KDE `kreadconfig`
- Windows：读取 `Internet Settings` 注册表
- 其他平台：仅环境变量回退
- 当前仅覆盖手动 HTTP/HTTPS/SOCKS 代理设置，PAC 暂未执行

### 网络测试工具

本地网络测试工具统一放在 `fixture_server/`：

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

如果只想单独验证 Rust crate 编译：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### 预编译策略

仓库直接提交各平台预编译产物：

- Android：`packages/rust_net/android/src/main/jniLibs/*/librust_net_native.so`
- iOS：`packages/rust_net/ios/Frameworks/*.dylib`
- macOS：`packages/rust_net/macos/Libraries/librust_net_native.dylib`
- Linux：`packages/rust_net/linux/Libraries/librust_net_native.so`（用于本地/原生验证；当前未声明 Linux Flutter plugin wrapper）
- Windows：`packages/rust_net/windows/Libraries/rust_net_native.dll`

`packages/rust_net/android/build.gradle` 会优先使用预编译 `jniLibs`，仅在缺失时回退到 Rust 编译。

如需强制 Android 源码编译：

```bash
RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true flutter build apk
```

### rust_net_core 集成

`rust_net_core` 作为独立包保留在 `packages/rust_net_core`。消费方可以通过 git `path` 依赖同时引用两个包（例如 Kino）。
