# rust_net workspace

[English](./README.md)


### 项目介绍

`rust_net` 是一个 Flutter/Dart HTTP SDK 工作区：对业务开放的 API 保持在 Dart
层，底层传输执行交给 Rust `reqwest` 内核。

这个仓库主要用于：

- 维护统一的领域契约（`rust_net_core`）
- 实现 FFI 传输层（`rust_net`）
- 管理 Rust 原生运行时与 Release 资产分发
- 提供本地 fixture/proxy 集成测试工具

### 仓库内容

- `packages/rust_net_core`：领域实体、异常定义、仓储接口契约
- `packages/rust_net`：Dart FFI 包、build hook 实现、Dio 适配器
- `packages/rust_net/native/rust_net_native`：基于 `reqwest` 的 Rust `cdylib`
- `fixture_server/`：本地 HTTP fixture 服务与代理冒烟测试工具
- `scripts/`：多平台原生库构建脚本

### 包详情

- `packages/rust_net_core`：纯 Dart 领域契约与模型（`RustNetRequest`、`RustNetResponse`、`RustNetException`、`HttpExecutor` 等）。
- `packages/rust_net`：基于 Rust `reqwest` 的 Dart FFI 传输实现，并提供 `Dio` 适配器集成。

### 本地开发

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

### 编译原生库

当 Rust 原生代码变更后，维护者可以本地重新编译各平台二进制做验证：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
./scripts/build_native_macos.sh release
./scripts/build_native_android.sh release
./scripts/build_native_ios.sh release
./scripts/build_native_linux.sh release
./scripts/build_native_windows.sh release
```

正式 tag 发布时，会由 GitHub Actions 产出多平台二进制、manifest 和
checksum，并上传到 GitHub Release。消费方构建时通过
`packages/rust_net/hook/build.dart` 自动拉取匹配平台的原生资产，不再要求把
预编译产物提交进仓库。

### Flutter 使用方式

`pubspec.yaml`：

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net
  rust_net_core:
    git:
      url: git@github.com:iamdennisme/rust_net.git
      ref: v2.0.0
      path: packages/rust_net_core
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

### Native Asset 分发

`packages/rust_net` 通过 `hook/build.dart` 和 `code_assets` 在构建时选择
并打包正确的 Rust 动态库。build hook 的解析顺序是：

1. 显式 manifest override
2. 维护者本地 `native/rust_net_native/target/*` 回退
3. 迁移期 legacy 产物回退
4. GitHub Release manifest + 二进制下载

维护者本地验证时，至少先构建宿主机 Rust 动态库：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### rust_net_core 集成

`rust_net_core` 作为独立包保留在 `packages/rust_net_core`。消费方可以通过 git `path` 依赖同时引用两个包（例如 Kino）。
