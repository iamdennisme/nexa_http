# Flutter SDK 编写契约

> 目的：保证 `nexa_http` 作为 Flutter SDK 时，只通过标准包管理、公开 Dart API 和标准 Flutter 构建链路完成宿主集成。

## 核心原则

`nexa_http` 的 monorepo 主架构以 [项目分层契约](./project-layering-contract.md) 为准：顶层只有 Flutter SDK 层和原生 native 层。`carrier package`、`build hook`、`release asset`、`clean-host consumer` 和 materialized native library 是两层内部或两层之间的机制，不是独立主层。

合格的 Flutter SDK 必须让宿主 App 只做这些事：

- 在 `pubspec.yaml` 声明依赖
- 执行 `flutter pub get`
- import 主包公开 API
- 执行 `flutter build` 或 `flutter run`

除此之外都属于 SDK 设计负担。宿主如果必须修改 native 工程、复制文件、手动注册插件、运行自定义脚本，或理解 SDK 内部包结构，应该视为 SDK bug 或短期、显式、可删除的临时变通方案（workaround）。

## 包边界规则

`nexa_http` 的业务入口只能是：

```dart
import 'package:nexa_http/nexa_http.dart';
```

宿主文档的标准依赖示例必须区分两件事：应用代码只 import `nexa_http` 主包 API；依赖声明必须同时包含 `nexa_http` 和目标平台需要的 `nexa_http_native_<platform>` carrier package。Runtime 示例不得 import carrier package、`nexa_http_native_internal`、plugin registrar、artifact resolver 或 FFI runtime helper。

标准 Git 依赖示例必须使用真实 release tag，或明确写成 `<real-release-tag>` 并说明需要替换。不得把 `vX.Y.Z` 当作可复制执行的 ref。

以下包可以作为内部协作包存在：

- `nexa_http_native_internal`
- `nexa_http_native_android`
- `nexa_http_native_ios`
- `nexa_http_native_macos`
- `nexa_http_native_windows`
- `packages/*/native/` 下的平台 FFI crate
- `native/nexa_http_native_core` 下的共享 Rust core

这些包在 runtime API 层必须保持实现细节。公开 API、README 示例、测试 fixture 和外部 consumer 示例都应该守住 `nexa_http` 主包 import 边界，但依赖声明需要显式列出目标平台 carrier package。

## SDK 自持 native 生命周期

SDK 必须自己处理：

- Flutter plugin registration
- native binary 或 native asset 准备
- artifact 下载、checksum 校验和缓存策略
- CocoaPods、Gradle、CMake、native assets 和 hook 接入
- 最终 App 打包

Carrier package 和 build hook 可以在内部协作，但正常集成路径不得要求宿主修改 `Podfile`、Xcode build phase、Gradle 文件、CMake 文件或 native 源码路径。宿主选择平台 package 是依赖声明，不是 native 工程改造。

编译后的动态库下载和集成发生在 Flutter SDK 层：platform carrier 的 `hook/build.dart` 调用 `nexa_http_native_internal` 的 release artifact materialization 逻辑，下载 manifest、选择目标平台文件、校验 checksum，并把动态库写入 target matrix 定义的 package-internal `packagedRelativePath`。`native/nexa_http_native_core` 不负责下载、缓存、pub-cache/workspace 判断或 Flutter App 打包。

## 正式配置面

如果集成需要 mirror、offline artifact、debug artifact path、enterprise distribution 或 release override，必须通过以下方式之一暴露：

- 公开 Dart 配置 API
- 文档化的 build-time environment variable
- 文档化的 Flutter/Dart define
- 文档化的 package-manager dependency shape

不得让用户通过修改 native build 文件或源码路径来配置 SDK。每个配置逃生口都必须写清楚默认值、支持平台，以及临时配置的删除条件。

## 失败报告契约

任何可能到达宿主 App、build hook、artifact resolver 或 consumer verification 命令的错误，都应该包含足够信息用于提交高质量 issue：

- 失败阶段：`pub get`、build、plugin registration、artifact download、artifact verification、native packaging 或 runtime init
- 平台与架构
- 期望的宿主操作
- SDK version 或 git ref
- 原始底层错误

目标不是让宿主开发者读源码修 SDK，而是让 issue 不依赖猜测就能被定位。

## 临时变通方案规则

宿主侧 native 工程修改默认是发布阻断项，除非它被明确标记为临时变通方案。临时变通方案必须包含：

- 精确的宿主修改步骤
- 存在原因
- 影响平台
- 跟踪 task 或 issue
- 删除条件

不要把临时变通方案写成标准示例。标准路径始终是包依赖（package dependency）加 Flutter 构建链路（Flutter build chain）。

## 规划检查清单

当任务触达 Dart SDK surface、carrier package、native asset、FFI package、release asset、artifact manifest 或 consumer verification 时，规划必须回答：

- 这个变更后的宿主依赖声明是什么？
- 宿主 runtime 代码是否仍只 import `package:nexa_http/nexa_http.dart`？
- 哪些内部包或 artifact 参与协作，它们如何被隐藏？
- download、verification、cache、registration、packaging 分别由谁负责？
- 需要暴露哪些正式配置，文档在哪里？
- 出错时用户能看到哪些 failure stage 和 platform 数据？
- 哪个 clean-host verification 能证明这个变更？

## 开发检查

实现完成前必须确认变更没有把 SDK 职责外包给宿主。当前仓库优先使用这些命令：

```bash
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
```

验证真实 release tag 或 release candidate 时使用：

```bash
fvm dart run scripts/workspace_tools.dart verify-release-consumer
```

如果当前机器无法覆盖某个平台，必须记录被跳过的平台，以及需要哪个 runner 或机器补验证。

## 发布阻断门禁

发布前，每个目标宿主平台至少要有一个干净宿主 App 通过：

1. `flutter create`
2. 添加 `nexa_http` 主包和目标平台对应的 `nexa_http_native_<platform>` 依赖
3. `flutter pub get`
4. import 并调用最小公开 `nexa_http` API
5. `flutter build` 或 `flutter run`
6. 验证 plugin registration 和 native artifact packaging

目标平台失败则阻断发布，除非本次 release 明确移除该平台。

## Scenario: Native build hook toolchain 环境自持

### 1. Scope / Trigger

- Trigger: 修改 `scripts/build_native_*.sh`、carrier `hook/build.dart`、CocoaPods/Gradle native packaging 或 clean-host verification。

### 2. Signatures

- `scripts/build_native_macos.sh <debug|release>`
- `scripts/build_native_ios.sh <debug|release>`
- `scripts/build_native_android.sh <debug|release>`
- `scripts/build_native_windows.sh <debug|release>`
- carrier hook 只能通过 `bash scripts/build_native_<platform>.sh debug` 准备 workspace artifact。

### 3. Contracts

- macOS 构建脚本必须通过 `xcrun --sdk macosx --show-sdk-path` 设置 `SDKROOT`，并给 C/C++ 编译 flags 加 `-isysroot ${SDKROOT}`。
- Rust target 准备必须先读取 `rustup target list --installed`，只安装缺失 target。
- `rustup target add` 必须有有界超时；当前脚本使用 `run_with_timeout 600`。
- build hook 不得要求宿主 App 在 Xcode、Podfile、Gradle 或 shell profile 中手工设置 SDK path、Rust target 或 C compiler。

### 4. Validation & Error Matrix

- `xcrun` 不存在或 SDK path 不存在 -> 构建脚本失败，错误包含 `macOS SDK path`。
- Rust target 缺失且下载超过 600 秒 -> 构建脚本失败，错误包含 `Command timed out` 和完整 `rustup target add` 命令。
- `TargetConditionals.h` 缺失 -> 优先检查脚本是否设置 `SDKROOT`/`-isysroot`，不要把修复写成宿主 Xcode 配置步骤。

### 5. Good/Base/Bad Cases

- Good: clean Flutter macOS consumer 只运行 `flutter build macos --debug`，hook 内部完成 SDK path 和 artifact 准备。
- Base: contributor 本机已安装 Rust target，脚本跳过 `rustup target add`。
- Bad: README 要求宿主执行 `export SDKROOT=...` 或手动复制 `.dylib`。

### 6. Tests Required

- `bash -n scripts/build_native_common.sh scripts/build_native_macos.sh scripts/build_native_ios.sh scripts/build_native_android.sh scripts/build_native_windows.sh`
- `cargo fmt --all --check`
- `cargo test --workspace`
- `fvm dart run scripts/workspace_tools.dart verify-external-consumer`
- `fvm dart run scripts/workspace_tools.dart verify-development-path`

### 7. Wrong vs Correct

#### Wrong

```bash
# 依赖宿主 shell profile，Flutter/Xcode 子进程可能拿不到。
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
flutter build macos
```

#### Correct

```bash
./scripts/build_native_macos.sh debug
```

脚本内部解析 `SDKROOT`、设置 `CC`、追加 `-isysroot`，并由 carrier hook 在 Flutter build 中调用。

## Scenario: Release consumer verification 使用真实 ref

### 1. Scope / Trigger

- Trigger: 修改 `verify-release-consumer`、release tag workflow、git dependency 示例、artifact manifest lookup 或 release asset URL 规则。

### 2. Signatures

- `fvm dart run scripts/workspace_tools.dart verify-release-consumer`
- 可选环境变量：`NEXA_HTTP_RELEASE_REF=<tag-or-ref>`
- 可选环境变量：`NEXA_HTTP_RELEASE_REPO_URL=<git-url>`

### 3. Contracts

- `verify-release-consumer` 必须使用真实 release tag/ref，不能把 `vX.Y.Z` 占位符写入临时 consumer pubspec。
- ref 解析顺序：显式 `NEXA_HTTP_RELEASE_REF`，否则当前 `HEAD` 的 exact tag。
- 当前工作区未打 tag 时，release consumer 验证必须快速失败并提示设置 `NEXA_HTTP_RELEASE_REF`。
- 当前未发布改动不能用旧 tag 证明；旧 tag 只能证明已发布 release consumer 路径仍可用。

### 4. Validation & Error Matrix

- `NEXA_HTTP_RELEASE_REF` 为空且 `HEAD` 没有 exact tag -> `StateError`，提示设置真实 ref。
- ref 是 `vX.Y.Z` -> `StateError`，提示不能使用占位符。
- git ref 不存在 -> `flutter pub get` 失败，说明目标 release/tag 不存在或未推送。

### 5. Good/Base/Bad Cases

- Good: `NEXA_HTTP_RELEASE_REF=v1.0.8 fvm dart run scripts/workspace_tools.dart verify-release-consumer`。
- Base: 在 release tag checkout 上直接运行命令。
- Bad: 在未打 tag 的开发分支上直接运行命令，并把 `vX.Y.Z` 当成通过条件。

### 6. Tests Required

- `fvm dart test test/workspace_tools_test.dart`
- `fvm dart test test/workspace_demo_and_consumer_verification_test.dart`
- 对已发布 tag 运行 `NEXA_HTTP_RELEASE_REF=<tag> fvm dart run scripts/workspace_tools.dart verify-release-consumer`

### 7. Wrong vs Correct

#### Wrong

```yaml
ref: vX.Y.Z
```

#### Correct

```bash
NEXA_HTTP_RELEASE_REF=v1.0.8 \
fvm dart run scripts/workspace_tools.dart verify-release-consumer
```
