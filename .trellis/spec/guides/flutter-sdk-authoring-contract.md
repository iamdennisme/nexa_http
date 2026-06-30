# Flutter SDK 编写契约

> 目的：保证 `nexa_http` 作为 Flutter SDK 时，只通过标准包管理、公开 Dart API 和标准 Flutter 构建链路完成宿主集成。

## 核心原则

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

宿主文档可以在依赖声明里提到当前分发模型需要的 carrier package；但 runtime 示例不得 import carrier package、`nexa_http_native_internal`、plugin registrar、artifact resolver 或 FFI runtime helper。

以下包可以作为内部协作包存在：

- `nexa_http_native_internal`
- `nexa_http_native_android`
- `nexa_http_native_ios`
- `nexa_http_native_macos`
- `nexa_http_native_windows`
- `packages/*/native/` 下的平台 FFI crate
- `native/nexa_http_native_core` 下的共享 Rust core

这些包在 runtime 层必须保持实现细节。公开 API、README 示例、测试 fixture 和外部 consumer 示例都应该守住 `nexa_http` 主包边界。

## SDK 自持 native 生命周期

SDK 必须自己处理：

- Flutter plugin registration
- native binary 或 native asset 准备
- artifact 下载、checksum 校验和缓存策略
- CocoaPods、Gradle、CMake、native assets 和 hook 接入
- 最终 App 打包

Carrier package 和 build hook 可以在内部协作，但正常集成路径不得要求宿主修改 `Podfile`、Xcode build phase、Gradle 文件、CMake 文件或 native 源码路径。

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

- 这个变更后的宿主集成面是什么？
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
2. 添加 `nexa_http` 和当前分发模型要求的 platform carrier dependency
3. `flutter pub get`
4. import 并调用最小公开 `nexa_http` API
5. `flutter build` 或 `flutter run`
6. 验证 plugin registration 和 native artifact packaging

目标平台失败则阻断发布，除非本次 release 明确移除该平台。
