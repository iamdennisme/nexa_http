# rust_net workspace

[English](./README.md)

## 项目概览

`rust_net` 是一个 Flutter/Dart 多包工作区，用于提供基于 Rust `reqwest`
内核的 HTTP 传输能力。对业务暴露的请求/响应 API 保持在 Dart 层，native
库分发由 `hook/build.dart` + `code_assets` 负责，而请求执行链路内部仍保留
RINF 风格的 Dart/Rust 异步通信通道。

仓库主要包含：

- `packages/rust_net_core`：纯 Dart 领域模型与接口契约
- `packages/rust_net`：传输包、build hook、Dio 适配器
- `packages/rust_net/native/rust_net_native`：Rust `cdylib`
- `fixture_server/`：本地 fixture 和代理测试工具
- `scripts/`：native 构建与发布辅助脚本

## 包职责

### `rust_net_core`

当你只需要共享请求/响应模型，而不需要 Rust 传输运行时时，使用这个包。它定
义了 `RustNetRequest`、`RustNetResponse`、`RustNetException` 和
`HttpExecutor`。

### `rust_net`

当你需要真正的 Rust 传输能力时，使用这个包。它对外暴露：

- `RustNetClient`
- `RustNetDioAdapter`
- 应用构建阶段使用的 native asset build hook

更详细的接入说明见
[`packages/rust_net/README.md`](./packages/rust_net/README.md)。

## Git 依赖接入

如果你的应用只 import `package:rust_net/...`，只声明 `rust_net` 即可。只有在
业务代码直接 import `rust_net_core` 时，才需要把它一并声明出来。

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

## 发布模型

发布由 tag 驱动。

1. 维护者推送 `v2.0.0` 这类 tag。
2. GitHub Actions 构建配置好的多平台二进制。
3. Workflow 将二进制、manifest 和 `SHA256SUMS` 发布到 GitHub Release。
4. 消费项目构建时执行 `packages/rust_net/hook/build.dart`，按目标平台解析并下
   载正确的 native asset。

当前 build hook 的解析顺序：

1. 通过 hook user-defines 显式指定 manifest
2. 维护者本地 `native/rust_net_native/target/*` 回退
3. 若 checkout 中仍残留旧产物，则走迁移期 legacy 回退
4. GitHub Release manifest + 平台二进制下载

仓库不再以“提交预编译产物”作为长期分发方式。

## 本地开发

仓库通过 `.fvmrc` 固定在 `Flutter 3.41.5` / `Dart 3.11.3`。

工作区检查：

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

本地维护 Rust crate：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

平台级验证脚本仍保留在 `scripts/`：

```bash
./scripts/build_native_macos.sh release
./scripts/build_native_android.sh release
./scripts/build_native_ios.sh release
./scripts/build_native_linux.sh release
./scripts/build_native_windows.sh release
```

## 测试工具

本地网络 fixture 工具位于 `fixture_server/`：

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

当你需要端到端验证请求方法、重定向、超时和代理行为时，优先使用这套 fixture
工具。
