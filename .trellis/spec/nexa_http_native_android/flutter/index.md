# nexa_http_native_android Flutter carrier 规范

> Android carrier 只把共享 Artifact Integration 接入 Android Flutter plugin、Native Assets hook 和自身 CodeAsset bindings；它不是第二套 runtime API。

## Platform Boundary

- `hook/build.dart` 只把 Android target 输入投影给 internal artifact preparer，再直接包装返回的 `File`。
- plugin registration 安装与 Android CodeAsset ID 对齐的 immutable bindings factory。
- Android artifact target、release filename 和 build script 来自 canonical target matrix。
- carrier 不拥有 HTTP execution、release download、workspace detection 或 Rust proxy source。

## Pre-Development Checklist

- [ ] 阅读 [Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md)、[项目分层契约](../../guides/project-layering-contract.md) 和 ADR-0002、0005。
- [ ] 修改 hook 时同步 `test/build_hook_test.dart`；修改 registration 时同步 plugin test。
- [ ] 不恢复 `jniLibs`、Gradle copy/build、manual loader 或 fallback。

## Quality Check

- [ ] `fvm dart test packages/nexa_http_native_android/test` 通过。
- [ ] hook 返回唯一 Android `CodeAsset`，并直接使用 preparation 返回文件。
- [ ] 宿主只需声明 carrier dependency，不修改 Android native 工程。
