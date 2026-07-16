# nexa_http_native_ios Flutter carrier 规范

> iOS carrier 只把共享 Artifact Integration 接入 iOS Flutter plugin、Native Assets hook 和自身 CodeAsset bindings；它不是第二套 runtime API。

## Platform Boundary

- `hook/build.dart` 投影 iOS device/simulator target，并直接包装 internal preparer 返回的 `File`。
- plugin registration 安装与 iOS CodeAsset ID 对齐的 immutable bindings factory。
- target、SDK variant、release filename 和 build script 来自 canonical target matrix。
- carrier 不拥有 HTTP execution、release download、workspace detection 或 SystemConfiguration proxy source。

## Pre-Development Checklist

- [ ] 阅读 [Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md)、[项目分层契约](../../guides/project-layering-contract.md) 和 ADR-0002、0005。
- [ ] 修改 hook 时同步 `test/build_hook_test.dart`；修改 registration 时同步 plugin test。
- [ ] 不恢复 Podspec artifact path、Frameworks materialization、`DynamicLibrary.process()` 或 fallback。

## Quality Check

- [ ] `fvm dart test packages/nexa_http_native_ios/test` 通过。
- [ ] hook 对 device/simulator tuple 返回唯一 iOS `CodeAsset`。
- [ ] 宿主只需声明 carrier dependency，不修改 Podfile 或 Xcode project。
