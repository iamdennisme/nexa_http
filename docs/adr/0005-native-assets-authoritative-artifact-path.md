# ADR-0005: Native Assets 是唯一 native artifact 路径

## 状态

Accepted

## 背景

当前 carrier 同时存在 Flutter Native Assets/CodeAsset 与 CocoaPods、Gradle、CMake、固定路径 `DynamicLibrary` loader 等传统打包或加载路径。macOS 构建产物已经出现两份携带相同 native payload 的 framework，且 runtime 实际加载的文件不一定是 CodeAsset、checksum 和 ABI verifier 所指向的同一文件。双轨路径会制造 artifact identity、target、checksum、ABI、code signing 和 runtime failure 归属上的歧义。

## 决策

Flutter Native Assets/CodeAsset 是所有支持平台唯一权威的 native artifact packaging 和 loading 路径。一个 target tuple 只能解析出一个 artifact；carrier hook 准备的文件、CodeAsset 打包的文件、runtime 使用的文件、ABI verifier 检查的文件和 clean-host runtime smoke 调用的文件必须是同一个权威 artifact。

迁移必须一次完成并删除 CocoaPods resource bundle、carrier-owned `jniLibs`/CMake copy、固定 bundle path、shadow loader、fallback branch 和其他与 Native Assets 并行的旧路径。本项目不为该迁移保留兼容模式或中间态；只要旧路径仍存在，迁移就未完成。

## 后果

- Target matrix 必须成为 target identity、artifact file 和 release metadata 的单一事实来源。
- Platform carrier 继续拥有 hook adapter 和 plugin registration，但不得再拥有第二套 artifact source 或 loader truth。
- Release gate 必须在公开 release 前对同一候选 artifact 执行 ABI verification 和真实 clean-host runtime smoke。
- Apple最终framework会被Xcode改写install name并重签名，因此Apple不能用prepared/package raw SHA相等作为跨packaging同一性条件，改用Mach-O UUID集合连接身份。Android与Windows Native Assets安装均为byte-for-byte copy，identity SHA必须等于raw SHA；Windows PE逐sectiondigest只用于失败诊断，不作为较弱的canonical identity。
- Dart build hook是半密闭进程，自定义`NEXA_HTTP_*`环境变量不会进入`Platform.environment`。Workspace source build通过共享fingerprint cache让Catalog producer与hook复用同一个File；candidate source通过workspace pubspec的`hooks.user_defines.<carrier>`显式传入，不保留环境变量shadow path。
- Runtime proof必须来自实际观测的结构化marker，artifact uniqueness必须限定到本轮最终App/APK ABI目录，不扫描同级中间产物。
- 如果未来确有外部兼容约束需要双轨，必须先由 owner 明确批准并用新的 ADR 重新打开本决定；实现者不得自行增加“临时 fallback”。

## 拒绝的替代方案

- Native Assets 与传统平台打包长期并存：拒绝，因为它保留两套事实来源。
- 先新增 Native Assets、以后再删旧路径：拒绝，因为未完成的中间态会被后续任务当成稳定架构。
- 以 CocoaPods、Gradle、CMake 为长期权威路径并删除 CodeAsset：拒绝，因为它延续四套平台装载知识，并削弱现有 hook、target matrix 和标准 Flutter 构建链路的价值。

## 当前来源

- `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_carrier_artifact.dart`
- `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_target_matrix.dart`
- `.trellis/spec/nexa_http_native_internal/dart/artifact-lifecycle.md`
- `.trellis/spec/nexa_http_native_android/flutter/index.md`
- `.trellis/spec/nexa_http_native_ios/flutter/index.md`
- `.trellis/spec/nexa_http_native_macos/flutter/index.md`
- `.trellis/spec/nexa_http_native_windows/flutter/index.md`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
