# ADR-0002: explicit platform carrier dependencies

## 状态

Accepted

## 背景

`nexa_http` 是 Flutter SDK，但 native integration 需要目标平台的 native artifact、plugin registration、build hook 和 dynamic-library loading。README 和 Flutter SDK 编写契约要求宿主 runtime 代码只 import `package:nexa_http/nexa_http.dart`，但 `pubspec.yaml` 必须同时声明主包和目标平台对应的 carrier package。

历史设计文档 `docs/superpowers/specs/2026-03-27-nexa-http-federated-native-design.md` 记录了 federated-style package composition：`nexa_http` 不依赖所有 platform packages，consuming app 显式选择自己 ship 的平台 package。

## 决策

宿主 App 使用显式 platform carrier dependencies：

- runtime code import `package:nexa_http/nexa_http.dart`
- dependency declaration includes `nexa_http`
- dependency declaration includes each target `nexa_http_native_<platform>` carrier package

`platform carrier` owns platform-specific native artifact/package integration，包括 build hook、plugin registration、native artifact packaging 和 runtime loader registration。

`public Dart SDK` 不拥有 native artifact production 或 platform package distribution policy。

## 后果

- 标准宿主集成路径是 package dependency + `flutter pub get` + public Dart API + standard Flutter build/run。
- 架构 review 不应建议宿主修改 Podfile、Gradle、CMake、Xcode project、Visual Studio project，或手工复制 native artifact 作为标准路径。
- 新平台需要新的 carrier package 和对应 platform FFI crate，而不是把平台逻辑塞进 `public Dart SDK`。
- `nexa_http_native_internal` 可以作为内部协作包处理 registry、target matrix 和 artifact materialization，但不成为宿主 runtime API。

## 替代方案

- `nexa_http` 自动依赖所有 platform carriers：拒绝。它会让 host build graph 包含不需要的平台 package。
- 宿主手动配置 native build/project：拒绝。它违反 Flutter SDK 编写契约。
- 让 `public Dart SDK` 自己处理 release artifact download 和 platform packaging：拒绝。它会混淆 public package 和 carrier package 职责。

## 提炼来源

- `docs/superpowers/specs/2026-03-27-nexa-http-federated-native-design.md`
- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http/README.md`
- `packages/nexa_http_native_android/README.md`
- `packages/nexa_http_native_ios/README.md`
- `packages/nexa_http_native_macos/README.md`
- `packages/nexa_http_native_windows/README.md`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
