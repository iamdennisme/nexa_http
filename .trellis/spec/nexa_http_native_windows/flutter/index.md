# nexa_http_native_windows Flutter carrier 规范

> Windows carrier 只把共享 Artifact Integration 接入 Windows Flutter plugin、Native Assets hook 和自身 CodeAsset bindings；它不是第二套 runtime API。

## Platform Boundary

- `hook/build.dart` 投影 Windows architecture，并直接包装 internal preparer 返回的 `File`。
- plugin registration 安装与 Windows CodeAsset ID 对齐的 immutable bindings factory。
- target、release filename 和 build script 来自 canonical target matrix。
- carrier 不拥有 HTTP execution、release download、workspace detection 或 registry proxy source。

## Pre-Development Checklist

- [ ] 阅读 [Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md)、[项目分层契约](../../guides/project-layering-contract.md) 和 ADR-0002、0005。
- [ ] 修改 hook 时同步 `test/build_hook_test.dart`；修改 registration 时同步 plugin test。
- [ ] 不恢复 CMake bundled library、Libraries materialization、manual DLL loader 或 fallback。

## Quality Check

- [ ] `fvm dart test packages/nexa_http_native_windows/test` 通过。
- [ ] hook 返回唯一 Windows `CodeAsset`，并由共享 shell resolver 处理 Git Bash。
- [ ] 宿主只需声明 carrier dependency，不修改 CMake 或 Visual Studio project。
