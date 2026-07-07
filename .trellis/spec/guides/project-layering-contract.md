# 项目分层契约

> 目的：固定 `nexa_http` monorepo 的主架构口径，避免把内部机制误当成独立架构层。

## 主分层

`nexa_http` monorepo 只有两个主层：

```text
nexa_http monorepo
├── Flutter SDK 层
└── 原生 native 层
```

`carrier package`、`build hook`、`release asset`、`clean-host consumer`、`native artifact` 不是新的主层。它们是两层内部或两层之间的机制。

## Flutter SDK 层

Flutter SDK 层包含：

- `packages/nexa_http`
- `packages/nexa_http_native_internal`
- `packages/nexa_http_native_android`
- `packages/nexa_http_native_ios`
- `packages/nexa_http_native_macos`
- `packages/nexa_http_native_windows`
- `packages/nexa_http_native_*/hook/build.dart`
- `scripts/workspace_tools.dart`
- README、verification docs 和 consumer-facing 文档

Flutter SDK 层负责：

- 对外提供 Dart HTTP SDK。
- 定义外部 App 的 package dependency 方式。
- 让宿主 runtime code 只 import `package:nexa_http/nexa_http.dart`。
- 在 Flutter build 时准备、下载、校验、打包 native 动态库。
- 在 runtime 注册并加载 native 动态库。
- 把 Dart request/config/error 映射到 FFI 调用。

### Flutter SDK 层内部角色

`packages/nexa_http` 是主 SDK：

- 拥有 public Dart API。
- 拥有 root import：`package:nexa_http/nexa_http.dart`。
- 可以拥有 Flutter plugin identity metadata。
- 不得暴露 native artifact 路径、plugin registration helper、release manifest parser 或 FFI lifecycle 作为 app-facing API。

`packages/nexa_http_native_internal` 是内部 native helper：

- 拥有 dynamic library loader、runtime registry、target matrix、carrier artifact preparation、release manifest parsing、artifact materialization、checksum verification 和 workspace/release 判断。
- 被 `nexa_http`、platform carrier package 和 workspace scripts 内部使用。
- 不得作为宿主 App runtime API 文档化。
- 不得依赖 `hooks` / `code_assets`，不得接收 `BuildInput` 或产生 `CodeAsset`。这些类型属于 platform carrier 的 adapter。

`packages/nexa_http_native_<platform>` 是 platform carrier package：

- 宿主 App 在 `pubspec.yaml` 中显式声明目标平台 carrier。
- carrier 是 Flutter platform implementation 和 dependency artifact，不是宿主 runtime API。
- carrier 负责 plugin registration、build hook、native asset packaging 和 platform-specific runtime loader strategy。
- carrier 不拥有 public HTTP API，也不拥有 request execution semantics。

## 原生 native 层

原生 native 层包含：

- `native/nexa_http_native_core`
- `packages/nexa_http_native_android/native/nexa_http_native_android_ffi`
- `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi`
- `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi`
- `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi`
- `scripts/build_native_android.sh`
- `scripts/build_native_ios.sh`
- `scripts/build_native_macos.sh`
- `scripts/build_native_windows.sh`
- `scripts/build_native_all.sh`

原生 native 层负责：

- Rust HTTP runtime。
- 统一 `nexa_http_*` C ABI。
- FFI request/response/error 数据结构。
- native memory ownership 和 free 函数。
- client registry、async execution、cancellation、callback 和 result free。
- native error JSON。
- shared proxy model 和 proxy matching。
- 各平台 proxy/system capability 读取。
- 编译平台动态库。

### 原生 native 层内部角色

`native/nexa_http_native_core` 是共享 Rust core：

- 拥有 HTTP execution、client registry、FFI data structure、ownership、error model、proxy abstraction 和 shared runtime logic。
- 不懂 Flutter。
- 不处理 `pubspec.yaml`、plugin registration、build hook、release asset、workspace/pub-cache probing 或 host app integration。
- 不直接读取 OS-specific proxy source。

Platform FFI crate 是 native platform adapter：

- 导出统一 `nexa_http_*` C ABI。
- 绑定 shared Rust core 和平台 proxy source。
- 读取平台 proxy/system capability，例如 Android `getprop`、Apple SystemConfiguration、Windows registry。
- 不复制 shared HTTP runtime logic。
- 不处理 Dart build hook 或 release artifact download。

Native build scripts 是维护者/CI 工具：

- 用于从 Rust crate 编译平台动态库。
- 不是外部 App 的标准集成步骤。

## 两层连接契约

两层通过三个契约连接：

1. Public SDK contract：宿主 runtime code 只 import `package:nexa_http/nexa_http.dart`。
2. FFI ABI contract：Flutter SDK 层只通过统一 `nexa_http_*` C ABI 调用原生 native 层。
3. Artifact packaging contract：原生 native 层提供动态库，Flutter SDK 层通过 carrier hook 把动态库物化并交给 Flutter build 打包。

## 外部 App 集成契约

外部 App 不是只依赖一个包。标准依赖是：

- `nexa_http`
- 一个或多个目标平台 carrier package，例如 `nexa_http_native_macos`

示例：

```yaml
dependencies:
  flutter:
    sdk: flutter

  nexa_http:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http

  nexa_http_native_macos:
    git:
      url: git@github.com:iamdennisme/nexa_http.git
      ref: v1.0.2
      path: packages/nexa_http_native_macos
```

宿主 runtime code 只能 import：

```dart
import 'package:nexa_http/nexa_http.dart';
```

宿主不得：

- import `nexa_http_native_internal`。
- import `nexa_http_native_<platform>` carrier package。
- 手动注册 plugin。
- 手动复制 `.so`、`.dylib` 或 `.dll`。
- 修改 `Podfile`、`Gradle`、`CMake`、Xcode project 或 Visual Studio project 来完成标准集成。
- 在正常集成路径运行 `scripts/build_native_*.sh`。

## 对外产物口径

对外有意义的产物只有两类：

1. Flutter SDK packages：`nexa_http` 和各平台 `nexa_http_native_<platform>` carrier package。`nexa_http_native_internal` 是内部传递依赖。
2. 发布版 native 下载产物：GitHub Release 上的 `.so` / `.dylib` / `.dll`、`nexa_http_native_assets_manifest.json` 和 `SHA256SUMS`。

Materialized native library 不是独立对外产物。它是 build 时由 carrier hook 从 workspace build output 或 release asset 物化到 carrier/App 内部路径的动态库。

## Native 下载与集成位置

下载触发点在 platform carrier 的 `hook/build.dart`。

carrier hook 只负责把 `BuildInput` 映射成 target OS / architecture / SDK tuple，并调用 `nexa_http_native_internal` 的 carrier artifact preparation。workspace/release 判断、packaging directory cleanup、workspace source build script 调用和 release materialization 必须集中在 `nexa_http_native_internal`。

下载和校验逻辑在 `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_release_consumer.dart`。

目标路径由 `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_target_matrix.dart` 的 `packagedRelativePath` 定义。

carrier 的 asset bundle 把物化后的动态库作为 `CodeAsset` 交给 Flutter build。

carrier plugin 注册 runtime loader，让 App 运行时能打开已打包的动态库。

## 检查清单

- [ ] 是否仍保持两层主架构，而不是新增伪层。
- [ ] 宿主依赖声明是否包含 `nexa_http` 和目标平台 carrier。
- [ ] 宿主 runtime code 是否只 import `package:nexa_http/nexa_http.dart`。
- [ ] `native_core` 是否只承担 Rust runtime 和 FFI contract。
- [ ] artifact download/materialization 是否仍在 Flutter SDK 层的 internal helper + carrier hook。
- [ ] 文档是否避免把 materialized native library 写成独立最终产物。
