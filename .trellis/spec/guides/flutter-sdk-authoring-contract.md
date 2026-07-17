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
- `native/nexa_http_native_apple_proxy` 下的共享 Apple proxy parser

这些包在 runtime API 层必须保持实现细节。公开 API、README 示例、测试 fixture 和外部 consumer 示例都应该守住 `nexa_http` 主包 import 边界，但依赖声明需要显式列出目标平台 carrier package。

意外进入 `lib/` 根目录、root export 或 public member 的 FFI/native implementation detail 不因此成为长期兼容 API。确认其不属于 HTTP semantics 后，必须直接删除或移入 `lib/src/`，并以 breaking version/CHANGELOG 表达影响；不得保留 deprecated alias、forwarding wrapper 或兼容 library。

## SDK 自持 native 生命周期

SDK 必须自己处理：

- Flutter plugin registration
- native binary 或 native asset 准备
- artifact 下载、checksum 校验和缓存策略
- CocoaPods、Gradle、CMake、native assets 和 hook 接入
- 最终 App 打包

Carrier package 和 build hook 可以在内部协作，但正常集成路径不得要求宿主修改 `Podfile`、Xcode build phase、Gradle 文件、CMake 文件或 native 源码路径。宿主选择平台 package 是依赖声明，不是 native 工程改造。

编译后的动态库下载和集成发生在 Flutter SDK 层：platform carrier 的 `hook/build.dart` 把 Flutter hook 输入映射成 target OS / architecture / SDK tuple，并把 Flutter hook output directory 传给 `nexa_http_native_internal`。该内部 module 负责 workspace/release 判断、显式 Rust target build、target-isolated materialization、manifest 下载、checksum 校验、single-flight lock、唯一 temp 和 replace。Workspace source build 与 Catalog producer共享 `.dart_tool/nexa_http_native/workspace/debug` 下按唯一release filename区分的fingerprint cache；release/candidate materialization仍写入hook output的target-keyed目录。产物不得写入carrier package的`jniLibs`、`Frameworks`或`Libraries`。

`nexa_http_native_internal` 不得依赖 `hooks` 或 `code_assets`，也不得接收 `BuildInput` 或产生 `CodeAsset`；这些 Flutter build hook adapter 类型保留在 platform carrier package。`native/nexa_http_native_core` 不负责下载、缓存、pub-cache/workspace 判断或 Flutter App 打包。

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

临时变通方案规则不授权 SDK 内部保留架构双轨。SDK 内部 packaging、loading、registration 或 verification 迁移必须遵守项目分层契约的原子完成规则；未经 owner 明确批准，不得增加 fallback、旧 loader 兼容分支或并行 artifact source。

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

实现完成前必须确认变更没有把 SDK 职责外包给宿主。合并 gate 统一使用完整 suite：

```bash
fvm dart run scripts/workspace_tools.dart verify-static
fvm dart run scripts/workspace_tools.dart verify-integration
```

验证未公开 Release Candidate 时使用：

```bash
fvm dart run scripts/workspace_tools.dart verify-release-candidate
```

单项 check 只用于本地诊断，不能替代完整 suite。如果当前机器无法覆盖某个平台，必须由动态 Actions matrix 的对应 runner 补齐，不能把 skipped platform 当通过。

## 发布阻断门禁

公开 release 前，每个目标宿主平台至少要有一个使用候选 artifact 的干净宿主 App 通过：

1. `flutter create`
2. 添加 `nexa_http` 主包和目标平台对应的 `nexa_http_native_<platform>` 依赖
3. `flutter pub get`
4. import 最小公开 `nexa_http` API
5. `flutter build` 或 `flutter run`
6. 实际执行一次 fixture HTTP request
7. 验证 plugin registration、Native Asset 加载、FFI client creation、callback delivery 和 response-body release

Android、iOS、macOS、Windows 任一目标失败都阻断发布。公开 GitHub Release 的创建或 promotion 必须依赖四个平台 gate 成功；先发布、后运行 consumer verification 不算发布门禁。

不得为赶发布时间而临时跳过或隐藏失败平台。平台移除是独立产品与架构决策，必须在 release 规划之前由 owner 明确批准，并在同一个 removal task 中删除对应 carrier、artifact target、CI job、文档和支持声明；它不能作为当前 release gate 的例外分支。

Release transaction 必须由明确 version 和 commit SHA 启动，不得由 public tag push 触发。候选文件只存放在私有 GitHub Actions artifacts；四平台验证前不得创建 public tag、draft/prerelease 或 GitHub Release。

候选 asset、manifest 和 checksums 只生成一次。Android、iOS、macOS、Windows gate 必须消费同一 candidate set，并记录/核对 immutable artifact digest。最终 publisher job 只能下载并发布这组已验证 bytes，不得重新 build、重命名或从另一 source 补文件。

任一 gate 失败时，workflow 只保留私有诊断 artifact，不产生 public release state。全部 gate 通过后，唯一 publisher job 才能为批准的 commit 创建 version tag 和 GitHub Release。旧 tag-triggered workflow/script 必须在同一个 clean cutover 中删除或重写。

## Scenario: Native build hook toolchain 环境自持

### 1. Scope / Trigger

- Trigger: 修改 `scripts/build_native_*.sh`、carrier `hook/build.dart`、CocoaPods/Gradle native packaging 或 clean-host verification。

### 2. Signatures

- `scripts/build_native_<platform>.sh <debug|release> --output-dir <dir> --target <rust-triple> [--target <rust-triple>...]`
- carrier hook 只能请求当前 target tuple；Catalog 可以按脚本分组，在一次 invocation 中传该 execution 的全部显式 target。

### 3. Contracts

- macOS 构建脚本必须通过 `xcrun --sdk macosx --show-sdk-path` 设置 `SDKROOT`，并给 C/C++ 编译 flags 加 `-isysroot ${SDKROOT}`。
- Windows 上 Dart `Process.run('bash', ...)` 可能命中 WSL stub，不能作为 build-script interpreter。workspace hook 与 Verification Catalog 必须共同调用 `resolveNexaHttpNativeBashExecutable()`，定位 Git for Windows 的 `bin/bash.exe`；找不到时以 `native build toolchain resolution` 结构化失败，不得切到 WSL 或另一套 build path。
- Windows 上 Dart `Process.start('flutter', ...)` 不保证按 `PATHEXT` 解析 `flutter.bat`。verification process runner 必须集中用 `FLUTTER_ROOT/bin/flutter.bat`（缺 root 时用 PATH 中的 `flutter.bat` 名称）；external/development/released consumer adapter 不得各自复制 Windows command 分支。
- Rust target 准备必须先读取 `rustup target list --installed`，只安装缺失 target。
- `rustup target add` 必须有有界超时；当前脚本使用 `run_with_timeout 600`。
- build hook 不得要求宿主 App 在 Xcode、Podfile、Gradle 或 shell profile 中手工设置 SDK path、Rust target 或 C compiler。
- workspace hook 与 Catalog producer必须共享 `nexaHttpNativeWorkspaceOutputDirectory(workspaceRoot)`，并以source fingerprint + target-scoped file lock做fast path；同tuple并发只build一次，native/Cargo/build-script/target tuple变化后必须失效，不能用“文件已存在”盲目跳过。
- Android CI必须在emulator启动前通过Catalog `native-build`预热同一workspace fingerprint cache，并使用轻量`aosp_atd` image；完整integration suite启动后只允许fingerprint fast path，不得因预热而重复Cargo build或复制prepared artifact。
- source fingerprint只遍历源码与构建输入，必须剪枝native crate下的`target/`、`build/`和`.dart_tool/`生成树；不得重复哈希数GB编译产物，也不得让output bytes反向改变source fingerprint。
- Dart build hook运行在半密闭环境中，除toolchain/proxy等allowlist变量外会剥离自定义环境变量。Artifact source选择不得依赖`NEXA_HTTP_*`环境变量；candidate directory/ref必须通过workspace root `pubspec.yaml`的`hooks.user_defines.<carrier>`进入`BuildInput.userDefines`。

### 4. Validation & Error Matrix

- `xcrun` 不存在或 SDK path 不存在 -> 构建脚本失败，错误包含 `macOS SDK path`。
- Windows 找不到 Git Bash -> 构建失败，错误包含 stage、platform、expected action 和已检查路径；不得调用 `C:\\Windows\\System32\\bash.exe`/WSL stub。
- Windows clean-host command 以裸 `flutter` 启动失败 -> process runner executable resolution contract 失败；不得要求宿主手工改 PATH 或让每个 consumer adapter自行包一层 shell。
- Rust target 缺失且下载超过 600 秒 -> 构建脚本失败，错误包含 `Command timed out` 和完整 `rustup target add` 命令。
- `TargetConditionals.h` 缺失 -> 优先检查脚本是否设置 `SDKROOT`/`-isysroot`，不要把修复写成宿主 Xcode 配置步骤。

### 5. Good/Base/Bad Cases

- Good: clean Flutter macOS consumer 只运行 `flutter build macos --debug`，hook 内部完成 SDK path 和 artifact 准备。
- Base: contributor 本机已安装 Rust target，脚本跳过 `rustup target add`。
- Bad: README 要求宿主执行 `export SDKROOT=...` 或手动复制 `.dylib`。

### 6. Tests Required

- `bash -n scripts/build_native_common.sh scripts/build_native_macos.sh scripts/build_native_ios.sh scripts/build_native_android.sh scripts/build_native_windows.sh`
- `fvm dart test packages/nexa_http_native_internal/test/nexa_http_native_shell_test.dart test/verification/integration_checks_test.dart`
- `fvm dart test test/verification/process_runner_test.dart test/verification/external_consumer_adapter_test.dart`
- `cargo fmt --all --check`
- `cargo test --workspace`
- Catalog `verify-integration` 对应 execution row，显式传入 fixture URL 与 device。

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

## Scenario: 已发布 release consumer 回归使用真实 ref

### 1. Scope / Trigger

- Trigger: 修改已发布版本的 consumer regression、git dependency 示例、artifact manifest lookup 或 release asset URL 规则。

### 2. Signatures

- `fvm dart run scripts/workspace_tools.dart check released-consumer --execution <id> --repo-url <url> --ref <real-ref> --fixture-url <url> --device <target-os>=<device-id>`
- `discoverNexaHttpNativeGitReleaseRef(packageRoot) -> NexaHttpNativeGitReleaseRef(repositorySlug, exactTag)`

### 3. Contracts

- `released-consumer` 必须显式接收真实 repo URL 与 release tag/ref，不能把 `vX.Y.Z` 占位符写入临时 consumer pubspec。
- `released-consumer` CLI不得从环境变量或命令执行workspace的`HEAD`/exact tag状态隐式猜测输入ref；build hook仍必须从实际dependency checkout的exact tag确定下载身份。
- Dart pub 的标准 Git checkout 中，checkout `origin` 指向本机 `.pub-cache/git/cache/<repo-hash>` bare repository，而该 bare repository 的 `origin` 才是 canonical GitHub URL。Release ref resolver必须解析这一层固定indirection，再以cache origin确定repository slug；这属于package-manager标准路径，不是fallback或第二artifact source。
- Resolver仍必须从dependency checkout的`HEAD`读取exact tag。不得从package version、branch、当前workspace HEAD或cache repository HEAD猜测tag，也不得递归追踪任意多层local remote。
- 当前未发布改动不能用旧 tag 证明；旧 tag 只能证明已发布 release consumer 路径仍可用。
- 本场景是已发布版本的诊断/回归检查，不属于 pre-publication Release Gate，不能替代 `verify-release-candidate`。

### 4. Validation & Error Matrix

- repo URL 或 ref 为空 -> usage error，提示显式提供 typed input。
- ref 是 `vX.Y.Z` -> `StateError`，提示不能使用占位符。
- git ref 不存在 -> `flutter pub get` 失败，说明目标 release/tag 不存在或未推送。
- dependency checkout origin是绝对local cache path，但cache repository没有canonical GitHub origin -> `release ref resolution`失败；不得把local path拼成Release URL。
- dependency checkout `HEAD`没有exact tag -> `release ref resolution`失败，即使cache origin和package version看起来有效也不得继续下载。

### 5. Good/Base/Bad Cases

- Good: 通过 `check released-consumer` 显式传入真实 repo URL、release ref、execution、fixture URL 与 device。
- Base: 对真实已发布 ref 运行诊断；checkout origin指向Dart pub bare cache，resolver通过cache的GitHub origin得到repository slug，并让宿主只依赖公开主包与目标 carrier。
- Bad: 把`.pub-cache/git/cache/...`当成unsupported remote，或使用`vX.Y.Z`、package version、隐式环境变量、旧 top-level command猜测release ref。

### 6. Tests Required

- `fvm dart test test/verification/cli_test.dart`
- `fvm dart test test/verification/released_consumer_adapter_test.dart`
- `fvm dart test packages/nexa_http_native_internal/test/nexa_http_native_release_consumer_test.dart`，使用真实Git命令构造“checkout origin为local bare cache、cache origin为GitHub、checkout HEAD为exact tag”的Dart pub拓扑，并断言解析出的repository slug/tag。
- 对已发布 tag 运行 `check released-consumer` 诊断

### 7. Wrong vs Correct

#### Wrong

```text
dependency checkout origin = /home/user/.pub-cache/git/cache/nexa_http-hash
→ 直接判定 unsupported remote
```

#### Correct

```bash
# Resolver先读取checkout origin，再读取唯一一层pub cache origin；tag只取checkout exact HEAD。
# 将<real-release-tag>替换为已经发布且包含本契约实现的真实tag。
fvm dart run scripts/workspace_tools.dart check released-consumer \
  --execution windows-x64 \
  --repo-url https://github.com/iamdennisme/nexa_http.git \
  --ref <real-release-tag> \
  --fixture-url http://127.0.0.1:8080/healthz \
  --device windows=windows
```

## Scenario: Carrier artifact preparation 保持 hook adapter-free

### 1. Scope / Trigger

- Trigger: 修改 `packages/nexa_http_native_internal/lib/src/native/`、platform carrier `hook/build.dart`、target matrix、release materialization 或 native asset packaging。

### 2. Signatures

- `prepareNexaHttpNativeCarrierArtifact({required String packageRoot, required String outputDirectory, required String targetOS, required String targetArchitecture, required String? targetSdk})`
- `prepareNexaHttpNativeWorkspaceArtifact({required String packageRoot, required String outputDirectory, required NexaHttpNativeTarget target})`
- `NexaHttpNativeTarget.materializationRelativePath(String profile)`
- `NexaHttpNativeTarget.buildScriptName`

### 3. Contracts

- platform carrier hook 负责读取 `BuildInput`，只把它映射为 target OS / architecture / SDK tuple。
- `nexa_http_native_internal` 负责 target resolution、workspace/release 判断、target-scoped output、workspace source build script 调用、release artifact materialization、streaming checksum 和 target lock。
- `nexa_http_native_internal` 不得依赖 `hooks` 或 `code_assets`，不得接收 `BuildInput`，不得返回 `CodeAsset`。
- carrier asset bundle 负责把已物化的动态库文件包装成 `CodeAsset`。
- target matrix 是 tuple、Rust triple、source/release filename、build script、execution、runner 和 Native Asset logical name 的单一事实来源。

### 4. Validation & Error Matrix

- Unsupported target tuple -> `NexaHttpNativeArtifactException`，stage 为 `native target resolution`。
- Workspace package 且 build script 存在 -> 运行 `bash scripts/build_native_<platform>.sh debug --output-dir <target-dir> --target <rust-triple>`；不得删除共享平台目录。
- Workspace build script 非 0 退出 -> `ProcessException`，message 包含 stdout 和 stderr。
- Pub-cache 或非 workspace package -> 走 release artifact materialization。
- Release asset checksum mismatch -> 删除本次唯一 temp、保留旧完整 destination，并抛出 `NexaHttpNativeArtifactException`，stage 为 `artifact verification`。

### 5. Good/Base/Bad Cases

- Good: carrier hook 调用 `prepareNexaHttpNativeCarrierArtifact`，然后用 carrier asset bundle 生成 `CodeAsset`。
- Base: release consumer 从 manifest streaming 下载目标 artifact，写入 hook output 的 target-keyed destination。
- Bad: carrier hook 自己调用 `shouldBuildNexaHttpNativeFromWorkspaceSource`、`Process.run` 或 `materializeNexaHttpNativeReleaseArtifact`。
- Bad: `nexa_http_native_internal` import `package:hooks` 或 `package:code_assets`。

### 6. Tests Required

- `fvm dart test packages/nexa_http_native_internal/test`
- `fvm dart test packages/nexa_http_native_<platform>/test/build_hook_test.dart`，平台文件分开跑，避免测试内修改 `Directory.current` 互相影响。
- `fvm dart test test/workspace_release_consistency_test.dart`
- `fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux`
- Catalog `verify-integration` 对应 execution row，显式传入 fixture URL 与 device。

### 7. Wrong vs Correct

#### Wrong

```dart
// carrier hook 同时拥有 workspace/release 判断、脚本执行和下载。
if (shouldBuildNexaHttpNativeFromWorkspaceSource(...)) {
  await Process.run('bash', <String>[script, 'debug']);
} else {
  await materializeNexaHttpNativeReleaseArtifact(...);
}
```

#### Correct

```dart
// carrier hook 只做 Flutter hook adapter。
final artifact = await prepareNexaHttpNativeCarrierArtifact(
  packageRoot: packageRoot,
  outputDirectory: Directory.fromUri(input.outputDirectory).path,
  targetOS: 'macos',
  targetArchitecture: targetArchitecture,
  targetSdk: null,
);
output.assets.code.add(
  NexaHttpNativeMacosAssetBundle.resolveFromFile(
    packageName: input.packageName,
    file: artifact,
  ),
);
```

## Scenario: Native Assets 是唯一 artifact packaging/loading 路径

### 1. Scope / Trigger

- Trigger：修改 carrier `hook/build.dart`、asset bundle、plugin runtime registration、target matrix、CocoaPods/Gradle/CMake native packaging、release artifact materialization、ABI verification 或 clean-host consumer。
- 本场景适用于 Android、iOS、macOS、Windows；不得把某个平台留在传统打包路径形成长期例外。

### 2. Signatures

- Artifact preparation：`prepareNexaHttpNativeCarrierArtifact({required String packageRoot, required String outputDirectory, required String targetOS, required String targetArchitecture, required String? targetSdk}) -> Future<File>`。
- Workspace cache：`nexaHttpNativeWorkspaceOutputDirectory(workspaceRoot)`、`nexaHttpNativeWorkspaceArtifactFile(workspaceRoot, target)`和`recordNexaHttpNativeWorkspaceArtifactFingerprint(workspaceRoot, target)`。
- Candidate hook defines：`candidate_directory`与`candidate_ref`必须成对出现在`hooks.user_defines.<carrier>`；producer必须把absolute directory序列化为`file:` URI，hook通过`input.userDefines.path(...)`解析directory，通过`input.userDefines[...]`读取ref。
- Consumer build projection：`externalConsumerBuildArguments({required ExternalConsumerPlatform platform, required Uri fixtureUrl}) -> List<String>`，path/candidate consumer与released consumer必须共同调用。
- Consumer fixture配置：`configureExternalConsumerFixture(Directory fixtureDirectory, {required String targetOS}) -> Future<void>`；Android与macOS的宿主工程配置必须在`flutter create`后、`pub get`和唯一一次build前通过这个共享入口完成。
- Verification command failure：`VerificationCommandFailure extends ProcessException`，通过`stdoutTail`与`stderrTail`向共享 runtime adapter 提供有界、可分类的child diagnostics。
- Android runtime smoke：`createFlutterRuntimeSmokeRunner(..., {ExternalAndroidInstallRetryWait waitForAndroidInstallRetry, ...}) -> ExternalRuntimeSmokeRunner`；只有已记录的 package-manager boot race 能使用该wait boundary。
- Target identity：`NexaHttpNativeTarget(targetOS, targetArchitecture, targetSdk, rustTargetTriple, sourceArtifactFileName, releaseAssetFileName, buildScriptName, integrationExecutionId, runner, nativeAssetName)`。
- Runtime registration：`registerNexaHttpNativeBindings(NexaHttpNativeBindingsFactory(assetId, create))`；同 ID 幂等，不同 ID 冲突失败，bindings 按 isolate lazy once。
- Native Asset identity：carrier 生成的 `CodeAsset` 必须使用项目唯一的 native asset name，并直接引用 preparation 返回的 `File`。
- Verification：Catalog `native-abi` check、clean-host runtime smoke 和 release-candidate gate 必须检查同一 target artifact。

### 3. Contracts

- 一个 `(sdkRef, targetOS, targetArchitecture, targetSdk, profile)` 只能对应一个权威 native artifact。
- Carrier hook 必须直接消费 preparation 返回的 `File`；不得忽略返回值后在 asset bundle 中重新推导或硬编码路径。
- Native Assets/CodeAsset 是唯一 packaging authority。CocoaPods resource bundle、carrier-owned `jniLibs`、CMake bundled-library copy、固定 bundle path 和备用 `DynamicLibrary` loader 不得作为第二 artifact source 存在。
- Runtime symbol resolution 必须绑定到 CodeAsset 打包的同一 artifact identity；不得验证 A、运行 B。
- Report 同时记录 prepared/package raw SHA-256 与 `identity_sha256`。Android与Windows的Flutter packaging都是byte-for-byte copy，identity必须等于raw digest；Apple framework会被Xcode改install name并重签名，identity固定为按architecture排序的Mach-O `LC_UUID`集合SHA-256。aggregate比较identity digest，两端raw值始终保留用于审计。
- Workspace integration的Catalog native-build producer先把同一组target一次构建到共享workspace cache并记录fingerprint；development path、external consumer和carrier hook只能复用这些File，不得通过被hook剥离的环境变量传递prepared目录，也不得二次build同一tuple。
- clean-host runtime成功必须实际观测单行`NEXA_HTTP_RUNTIME_PROOF`，且 request、callback、body consume/release、client close五个字段全为`true`；只有marker已完成时才允许忽略App主动退出后Flutter DDS teardown的`ProcessException`。
- clean-host fixture必须依次输出`NEXA_HTTP_RUNTIME_PHASE binding_ready`、`app_mounted`、`client_built`、`request_started`、`response_received`、`client_closed`，最终才输出proof。Catch必须把错误通过JSON编码的`NEXA_HTTP_RUNTIME_FAILURE`写到stdout；`NexaHttpException`包含type/message/kind/uri/diagnostics，不能只依赖release Android不可见的stderr或泛化`toString()`。Tracker只把proof计入成功，但零proof错误必须附带本轮去重phase和failure，区分Dart isolate/Flutter mount/client construction/native callback/body/close卡点；phase/failure不能替代proof。
- Android clean-host只允许一次`flutter build apk --release`，并在这次build中注入`127.0.0.1` fixture URL。Flutter app模板只在debug/profile manifest默认声明`android.permission.INTERNET`，因此path/candidate consumer与released consumer必须在build前共同调用fixture配置入口，把恰好一条`<uses-permission android:name="android.permission.INTERNET"/>`写入`android/app/src/main/AndroidManifest.xml`；不能依赖debug/profile manifest，也不能各自维护配置实现。两个consumer必须复用同一个build-argument projection，不能各自拼装define。Runtime row必须复用`app-release.apk`，按`adb install -t -r`、`adb logcat -c`、一次`adb reverse tcp:<fixture-port> tcp:<fixture-port>`、`adb shell am start -W`顺序启动；reverse端口直接来自fixture URL并发生在Activity启动前，不得依赖emulator特殊宿主地址、调用`flutter run`或启动debug APK进入VM-service/debug attach路径。启动后只对同device的`flutter:I`日志执行最多60次有界轮询；真实ATD冷启动可能在第30次之后才交付callback，仍要求恰好一条完整marker，不得扫描无关system日志或依赖固定sleep猜测日志已flush；proof判定结束后best-effort force-stop fixture，避免污染同device后续row。
- Android readiness 分两层：workflow 的 `service check package` 只做有界 binder gate；共享 runtime adapter 在真实 `adb install -t -r` 处识别 `PackageManagerInternal.freeStorage` 加 `null object reference` 的已记录竞态。只有该 typed failure 能以2秒间隔对同一设备、同一 `app-release.apk` 最多尝试3次；其他安装错误立即失败。成功恢复只代表可以继续运行，最终仍必须取得完整 `NEXA_HTTP_RUNTIME_PROOF`，不得把 retry 本身当作 clean-host success。
- Android fixture输出成功marker后不得主动`exit(0)`；由验证端观测marker后结束row。iOS/macOS/Windows可以在短暂flush窗口后退出，但任何平台的process exit code都不能替代marker。
- uniqueness只扫描本轮最终distribution：iOS/macOS为唯一`.app`，Android emulator row为`android-x64` APK的`lib/x86_64`，Windows为runner distribution。不得递归扫描整个Xcode Products或把不同Android ABI计为重复payload。
- Windows export解析只接受symbol工具输出行尾的真实token；`dumpbin` banner中的临时目录/App名称即使以`nexa_http_`开头也不是export。
- Candidate consumer pubspec中的path define必须跨平台使用`file:` URI，例如Windows `D:\a\repo\candidate`写成`file:///D:/a/repo/candidate`。不得把带盘符和反斜杠的原生Windows绝对路径直接写入YAML；`HookInputUserDefines.path()`按URI-reference解析该值，直接写原生路径会让盘符被当成scheme并使Native Assets build失败。
- Target matrix 是 target tuple、build target、source artifact、release file name 和 packaging identity 的单一事实来源。Workflow、shell、Gradle、Podspec、CMake 不得维护一份独立 target/path 表。
- 迁移必须在同一个任务内删除所有旧 packaging/loading 代码、测试和文档。不提供 fallback，不接受“先双轨、后续再清理”。
- clean cutover 不允许 deprecated alias、forwarder、compatibility wrapper 或“临时”双轨；rollback 只能整体 revert 完整变更。

### 4. Validation & Error Matrix

- Target tuple 无匹配项 -> `native target resolution` 失败，不允许 fallback 到 host architecture 或默认文件。
- Preparation 返回文件不存在 -> `native packaging` 失败，错误包含 target tuple 和期望动作。
- App 中出现两个导出 canonical `nexa_http_*` ABI 的 payload -> 验证失败，阻断合并和发布。
- Android emulator已报告boot complete但package binder不可见 -> CI继续通过`wait_android_package_service.sh`有界等待；超时阻断row，不启动clean-host runtime。
- Package binder已可见但真实install命中`PackageManagerInternal.freeStorage`与`null object reference` -> 对同一命令最多3次、间隔2秒恢复；第3次仍失败时报告attempt/device/APK/final tails并阻断row。
- Install诊断缺失、只有一个签名片段、出现invalid APK/signature/storage/device等其他错误，或抛普通`ProcessException` -> 第一次立即失败、零等待；不得rebuild、uninstall、换profile或切换artifact source。
- ABI verifier 检查的文件与 runtime smoke 加载的 artifact identity 不一致 -> 验证失败。
- Workspace hook缺少或读到不匹配fingerprint -> 在共享cache中重建该tuple；不得读取旧integration目录或fallback到第二artifact source。
- candidate directory/ref仅有一个、类型错误或路径不存在 -> hook直接失败；不得回退workspace/release source。
- Windows candidate directory以`D:\...`原生路径而不是`file:///D:/...`写入user-defines -> hook path解析或Native Assets build失败；修复producer序列化，不得增加另一路径探测或fallback。
- Android Flutter stdout无marker且清空后的同device filtered logcat在有界轮询内也无marker -> runtime失败；不得把App启动、DDS连接或进程退出当作lifecycle proof。
- runtime无proof -> 错误必须包含`phases=<本轮去重顺序>; failures=<结构化错误>`；完全没有phase表示Dart fixture未进入可观测main，停在`request_started`且有failure表示execute以异常结束。不得把phase/failure当成功证据。
- Android直接启动debug APK后只出现Dart VM service而无fixture marker -> build profile错误；consumer统一改用唯一release APK，不能继续延长轮询或恢复`flutter run`。
- Android main manifest不存在、XML中缺少`<manifest>`根元素或已包含多条INTERNET permission -> fixture配置失败并阻断build；不得改用debug/profile APK或重复插入权限。
- Workspace build 产物 architecture 与请求 target 不一致 -> 验证失败，不得使用 host build 代替。
- 搜索到已删除的 Pod resource bundle、legacy `jniLibs`/CMake copy 或固定 loader path -> 架构迁移未完成。

### 5. Good/Base/Bad Cases

- Good：hook 根据 target matrix 准备一个文件，将该文件作为 CodeAsset 打包；runtime smoke 打开并调用同一 artifact；App 内只有一份导出 public ABI 的 payload。
- Good：Android fixture在唯一release build前由共享配置器把main manifest从零条INTERNET permission变为恰好一条，path/candidate与released consumer行为一致。
- Good：package binder已可见但内部install path短暂未ready；共享adapter对同一release APK恢复后，继续原有logcat/reverse/start/proof/cleanup链路。
- Base：workspace source build 与 release download 来源不同，但最终都收敛到同一个 target-keyed CodeAsset contract。
- Bad：macOS 同时生成 Native Assets framework 和 CocoaPods resource bundle，runtime 固定打开后者。
- Bad：Android/Windows 同时让 CodeAsset 和 `jniLibs`/CMake 各复制一份 native library。
- Bad：为降低风险保留 `try Native Assets, catch then open legacy path`。
- Bad：release APK依赖只存在于`src/debug`或`src/profile`的INTERNET permission，或两个consumer分别修改manifest导致规则漂移/重复。
- Bad：把所有`adb install`错误都当作emulator readiness、在workflow加固定sleep/retry，或恢复后省略runtime proof。

### 6. Tests Required

- Carrier hook tests：断言 preparation 返回的 `File` 被直接交给 CodeAsset，不重新解析 packaged path。
- Target matrix tests：覆盖全部支持 tuple，并断言请求 architecture 真正驱动 workspace build target。
- Artifact uniqueness test：对构建完成的 App 扫描 public `nexa_http_*` exports，每个 target 只允许一个 payload。
- Proof report test：schema v2拒绝缺失raw/identity digest、相对路径、payload count非1、lifecycle false、target/asset/identity mismatch；aggregate精确覆盖9个target和4个平台runtime。
- ABI test：对最终 CodeAsset artifact 做 exact missing/unexpected symbol comparison。
- Runtime smoke：clean host 必须实际创建 client、执行 fixture HTTP request、接收 callback 并释放 response body。
- Runtime phase test：生成fixture的六个phase必须按binding/mount/client/request/response/close顺序出现，proof在最后；catch的JSON failure marker必须先于stderr；tracker零proof错误必须只报告本轮去重phase与failure。
- Workspace reuse test：Catalog producer与两个不同hook output请求返回同一个共享cache File，build invocation保持一次；source或target tuple变化会失效。
- Hook config test：candidate user-defines的相对目录按workspace pubspec base path解析，absolute POSIX/Windows目录由consumer producer序列化为`file:` URI，directory/ref成对传给preparer；自定义环境变量不参与contract。
- Android marker test：path/candidate与released consumer都模拟无INTERNET permission的Flutter main manifest，并断言唯一一次Flutter release APK build开始前manifest已包含恰好一条permission、build包含fixture define并产出`app-release.apk`；随后按install、清空logcat、`am start -W`、有界轮询、force-stop执行且不存在`flutter run`；覆盖首次精确竞态后成功、非匹配与untyped立即失败、三次耗尽、延迟到达、旧marker、零marker、重复marker和结束后的fixture清理。
- Release gate：Android、iOS、macOS、Windows 全部通过候选 artifact runtime smoke 后才允许公开 release。
- Legacy absence test：搜索并拒绝旧 resource bundle、固定 loader path、并行 `jniLibs`/CMake copy 和 fallback branch。

### 7. Wrong vs Correct

#### Wrong

```dart
final prepared = await prepareNexaHttpNativeCarrierArtifact(...);
output.assets.code.add(await AssetBundle.resolveByHardCodedPath(input));

try {
  return openNativeAsset();
} catch (_) {
  return DynamicLibrary.open(legacyBundledPath);
}
```

```yaml
hooks:
  user_defines:
    nexa_http_native_windows:
      candidate_directory: "D:\\a\\repo\\candidate"
```

```bash
flutter build apk --debug --target-platform=android-x64
flutter run -d emulator-5554 --debug --no-resident
```

```xml
<!-- 错误：release使用的src/main manifest没有网络权限。 -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application />
</manifest>
```

#### Correct

```dart
final artifact = await prepareNexaHttpNativeCarrierArtifact(...);
output.assets.code.add(
  await AssetBundle.resolveFromFile(
    packageName: input.packageName,
    file: artifact,
  ),
);
```

```yaml
hooks:
  user_defines:
    nexa_http_native_windows:
      candidate_directory: "file:///D:/a/repo/candidate"
```

```bash
flutter build apk --release --target-platform=android-x64 \
  --dart-define=NEXA_HTTP_FIXTURE_URL=http://127.0.0.1:8080/healthz
adb -s emulator-5554 install -t -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5554 reverse tcp:8080 tcp:8080
adb -s emulator-5554 shell am start -W -n \
  com.example.nexa_http_external_consumer_fixture/.MainActivity
```

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
  <application />
</manifest>
```

Runtime、ABI verification 和 clean-host smoke 必须解析并使用这个 CodeAsset 所代表的同一 artifact identity。

## Scenario: Public Dart API clean cutover

### 1. Scope / Trigger

- Trigger：修改 `packages/nexa_http/lib/nexa_http.dart`、`lib/src/api/api.dart`、`RequestBody`、`ResponseBody`、ffigen output、公开示例或 consumer fixture。
- 当 review 发现 FFI type、native ownership helper、artifact/runtime helper 或内部 mutable payload 可以从受支持 public surface 访问时，必须应用本场景。

### 2. Signatures

- 唯一受支持的宿主 runtime entrypoint：`import 'package:nexa_http/nexa_http.dart';`。
- Public HTTP types 以 ADR-0001 的清单为准。
- 唯一 request execution signatures：`NexaHttpClient.newCall(Request) -> Call`、`Call.execute() -> Future<Response>`、`Call.cancel() -> void`。
- `Callback`、`Call.enqueue()`、`Call.clone()` 和 `NexaHttpClient.execute(Request)` 不属于 public surface。
- 唯一 byte-backed request-body factory：`RequestBody.takeBytes(Uint8List bytes, {MediaType? contentType})`。`RequestBody.bytes(...)`、实例 `bytes()`、request-side `byteStream()` 和 `payloadBytes` 不属于 public surface。
- 唯一 public failure type：`NexaHttpException(kind: NexaHttpFailureKind, message: String, uri: Uri?, diagnostics: Map<String, Object?>?)`。
- `NexaHttpFailureKind` 的稳定值只有 `canceled`、`timeout`、`network`、`invalidRequest`、`configuration`、`unavailable`、`internal`。旧 string `code`、error `statusCode`、`isTimeout` 和 `details` 不属于 v2 public surface。
- 共享 ABI types 必须位于 `nexa_http_native_internal/lib/src/native/`；四个平台 carrier 分别生成与自身 CodeAsset ID 对齐的 `lib/src/native/nexa_http_native_ffi.dart`。主包不得拥有 `DynamicLibrary` lookup bindings。
- Internal body adoption 和 raw payload access 只能由 `native transport` 内部调用，不提供 public function/getter。

### 3. Contracts

- `packages/nexa_http/lib/` 根目录除正式 public entrypoint 外，不得出现可被宿主当成第二入口的 FFI/native library。
- Root exports 只包含 app-facing HTTP semantics；FFI structs、pointer ownership、native body adoption、platform registration 和 artifact resolution 必须留在内部。
- Byte-backed `RequestBody` 构造必须接管调用者提供的 `Uint8List`，不得在构造期做 defensive snapshot；调用者在构造后不得继续修改该 buffer。
- `takeBytes` 是 ownership-transfer 语义，不是借用。Public RequestBody 只保留 `text(...)`、`contentLength` 和 `contentType`，不提供 raw/full-body read API。
- Request mapper、内部 DTO 和 transport handoff 必须保持同一个 request-body backing-buffer identity，不得逐层复制。
- 每次非空 body dispatch 只允许一次完整 Dart-to-native body copy：把 canonical Dart buffer 写入 FFI-owned request memory。空 body 必须零 allocation、零 copy；构造、mapping、DTO 和 encoder 前置阶段不得产生额外完整 copy。
- Request encoder 必须成功完成 native body allocation/copy 后，才把 request ID 注册为 callback-outstanding。Encoder 在 dispatch 前失败时 native 不会 callback，不得留下 pending entry 或等待 dispose drain。
- Text body 只编码一次；encoder 已返回 `Uint8List` 时必须直接接管。仅当自定义 encoder 返回 generic `List<int>` 时，允许一次必要的 `Uint8List` normalization copy，且之后仍不得在 dispatch copy 前重复复制。
- `RequestBody` 不得公开 transport 专用 mutable backing buffer。
- `ResponseBody` 可以公开读取和 `close()` 语义，但不得公开 native ownership adoption constructor/helper。
- Call 是 one-shot execution owner。重复同一 Request 时必须重新调用 `newCall(request)`，不得通过 clone 或第二 client execution facade 复用执行状态。
- Future 是唯一 async completion model；不得保留 Java-style callback adapter 作为 public compatibility API。
- `Call.cancel()` 在 execute 前、execute 中和完成后都必须幂等；`isCanceled` 记录 cancellation intent，一旦为 true 不得恢复。
- Dart/native cancellation handshake 必须使用一个线性化点同时决定 terminal winner 与 callback expectation。现有 `nexa_http_client_cancel_request(...)->u8` 返回 `1` 时表示 cancel 已被接受且 callback 必须被抑制；返回 `0` 只表示 cancel 未被接受。对于 `execute_async` 已返回 `1` 且 Dart registry 仍标记 callback-outstanding 的合法 request，返回 `0` 表示 Callback Commit 已发生，Dart 不得完成 canceled，必须等待 callback response/error；任意 unknown/already-removed request ID 不承诺 callback。
- Cancellation 先取得线性化点时，Future 必须以 `NexaHttpException(kind: NexaHttpFailureKind.canceled)` 结束。Callback Commit 先取得线性化点时，稍后的 cancel 不得覆盖 callback result。
- Response 已经完成后 cancel 不改变 terminal result，也不得再次转发 native cancel；第二次 execute 必须抛 `StateError`，不得伪装成 network/canceled failure。
- `NativeCallable` 只能在所有仍可能 callback 的 request 清空后关闭。Accepted cancel 不得留下永久 tombstone；callback-committed request 在 dispose 后仍必须等待 callback delivery。
- `ResponseBody` 是 single-consumption owner。`string()` 直接 decode adopted native view 后释放；非空 native-adopted body 的 `bytes()` 只做一次 native-to-Dart copy 后释放；Dart-buffered body直接转移已拥有的 buffer，空 body不额外复制；`close()` 零复制且幂等。
- Decoder、transport payload、response mapper 和 Response constructor 必须传递同一个 body view，不得逐层 defensive copy。
- 对每个非 null callback result，response decoder 是 binary-result ownership 的唯一裁决点：error/empty/malformed 路径立即释放，非空成功路径把 exactly-once release 转移给 `ResponseBodyOwner`。Data source 不得再根据 `body_len` 猜测并二次 free。
- Empty response 在释放 binary result 前必须先 snapshot `statusCode` 等仍需返回的标量；释放后不得继续读取 FFI struct view。
- Request/Response 两侧的 buffered single-event `byteStream()` 都必须删除；没有 incremental native delivery、cancellation 和 backpressure 时不得把全量 buffer 命名为 streaming API。
- Native finalizer 只允许作为 abandoned body 的安全兜底，正常成功路径必须确定性释放。
- `build_runner` 的 package-local `build.yaml` 必须把 Freezed、json_serializable 和 combining builder 的 `generate_for` 限定到 `lib/**.dart`；test fixtures 不属于 codegen 输入。
- 意外 public API 的清理采用 clean cutover：删除旧 symbol 和旧 import path，不提供 deprecated alias、compatibility export 或 forwarding wrapper。
- Breaking removal 必须同步 package version/release notes、CHANGELOG、README 和 consumer verification；不得用兼容代码掩盖破坏性变化。
- Application control flow 只能依赖 `NexaHttpFailureKind`。`message` 与 `diagnostics` 是诊断信息，不承诺可枚举 schema；native code、FFI stage 和 native message 不得提升为新的 public kind。
- Cancellation -> `canceled`；reqwest timeout -> `timeout`；其他 HTTP execution network failure -> `network`；URL/method/header/request validation -> `invalidRequest`；client/proxy configuration failure -> `configuration`；carrier registration、dynamic-library/symbol/bootstrap/dispatch availability failure -> `unavailable`；ABI corruption、malformed error payload、invalid handle、serialization、unknown native code -> `internal`。
- HTTP 4xx/5xx 必须返回普通 `Response`，不得仅因 status code 抛 `NexaHttpException`。
- 第二次 Call execution、client use-after-close、第二次 Response Body consumption 等 programmer/lifecycle misuse 必须使用 `StateError`，不得伪装为 HTTP Failure。

### 4. Validation & Error Matrix

- `lib/` 根目录出现未批准的第二 Dart library -> public API contract test 失败。
- Root export 包含 FFI binding、native helper 或 internal carrier type -> public API contract test 失败。
- Root export 或 public class 仍包含 `Callback`、`enqueue()`、`clone()` 或 direct client `execute(request)` -> public API contract test 失败。
- Public RequestBody 仍包含 `bytes(...)` factory、实例 `bytes()`、`byteStream()` 或 `payloadBytes` -> clean-cutover contract test 失败。
- Public NexaHttpException 仍包含 string `code`、error `statusCode`、`isTimeout`、`details` 或 raw native-code subtype -> clean-cutover contract test 失败。
- Public class 暴露 mutable transport backing bytes -> API review 失败。
- Pre-execute cancel 与 active cancel 返回不同 public error type -> contract test 失败。
- Native cancel 返回 `1` 后仍调用 callback -> cancellation ABI contract 失败。
- Callback 已 commit 时 native cancel仍返回 `1`，或 Dart把结果改成 canceled -> terminal linearization contract 失败。
- 成功dispatch且仍callback-outstanding的request在native cancel返回 `0` 后，dispose提前关闭 callback handle、callback未到达、重复完成 Future 或未释放 result -> ownership test 失败。
- 非空 native-adopted ResponseBody `bytes()` 发生零次或多于一次 copy -> ownership/performance test 失败；零次会返回释放后失效的 native view，多次会造成不必要开销。Dart-buffered body 和空 body 不适用该 exactly-one-copy断言。
- `string()` 在 decode 前复制完整 byte buffer -> performance contract 失败。
- Mapper 或 Response construction 创建第二份完整 body buffer -> performance contract 失败。
- RequestBody construction、request mapper 或 DTO handoff 创建第二份完整 request body buffer -> performance contract 失败。
- 非空 request dispatch 发生零次或多于一次 Dart-to-native full-body copy -> ownership/performance contract 失败；零次意味着错误借用 Dart heap memory，多次意味着重复复制。空 request body若分配或调用body copier同样失败。
- 非空 request body allocator返回null -> `NexaHttpFailureKind.internal`；不得按empty body继续，也不得归为availability failure。
- Request encoder失败前已经注册 pending request -> dispose 永久等待一个不可能到达的 callback，属于 lifecycle failure。
- Decoder 和 data source 同时释放同一个 callback result -> double free；两者都不释放 error/empty result -> leak。
- Empty result释放后再读取 `status_code`/pointer field -> use-after-free，可能表现为状态码变成0或随机值。
- 调用者在 byte-backed RequestBody 构造后继续修改已转移所有权的 buffer -> 违反 public ownership contract。
- 第二次消费 Response Body 未抛 `StateError` -> lifecycle contract 失败。
- Internal source 仍 import 已删除的 root bindings path -> analyze/compile 失败，必须统一迁移到 `lib/src/`。
- CHANGELOG 或版本没有记录 breaking removal -> release gate 失败。
- 为旧 symbol 新增 deprecated wrapper/alias -> legacy absence test 失败。
- Unknown Rust/native error code 直接成为新的 public kind 或 string control value -> normalization contract 失败。
- Malformed native error JSON/DTO 暴露 `FormatException`、schema exception 或 raw callback error -> normalization contract 失败，必须收敛为 `internal`。
- Carrier 未注册、library/symbol 打开失败或 dispatch unavailable 暴露裸 `StateError`/`ArgumentError` -> normalization contract 失败，必须收敛为 `unavailable`。
- `build_runner` 扫描 `test/` 并因 fixture package、analyzer cycle 或 test-only import 失败 -> codegen scope错误；必须通过 `build.yaml` 收敛到 `lib/**.dart`。

### 5. Good/Base/Bad Cases

- Good：宿主只看到 `NexaHttpClient`、Request/Call/Response 等 HTTP semantics；bindings 和 ownership helpers 位于 `lib/src/`。
- Good：decoder 在空 body 分支先保存 status，再 free result并返回 Dart-owned empty owner；非空分支把 result release交给 native owner。
- Base：package 内部 tests 可以直接测试 `lib/src/` implementation，但 clean-host fixture 只能 import root API。
- Bad：`lib/nexa_http_bindings_generated.dart` 可被 consumer 直接 import。
- Bad：为了兼容旧用法保留 `@Deprecated()` 的 `payloadBytes` 或 `adoptResponseBodyBytes()` 转发函数。
- Bad：root API 同时提供 public HTTP API 和 native integration escape hatch。
- Bad：同时支持 `client.newCall(request).execute()` 和 `client.execute(request)`。
- Bad：保留 `enqueue(Callback)` 作为 deprecated compatibility path。
- Bad：同时保留 `RequestBody.bytes(payload)` 和 `RequestBody.takeBytes(payload)`，或让实例 `bytes()` 返回已转移 ownership 的 mutable buffer。
- Bad：先 `pending.register(requestId)` 再执行可能失败的 request-body encoder，或让 data source 和 decoder各自判断是否 free callback result。

### 6. Tests Required

- Public surface source test：断言 `lib/` 根目录只有批准的 public library，并检查 root export allowlist。
- Negative contract test：拒绝 generated bindings、body adoption helper、raw payload getter 和 carrier/runtime types 出现在 public allowlist。
- Execution surface test：public allowlist 只允许 `newCall()`、`Call.execute()` 和 `Call.cancel()`，并断言 callback/clone/direct-execute symbols 不存在。
- Request Body surface test：只允许 `takeBytes(...)`、`text(...)`、`contentLength` 和 `contentType`，并断言旧 factory/read/stream/raw-payload symbols 不存在。
- Failure surface test：穷举七个 `NexaHttpFailureKind`，断言旧 code/status/timeout/details 字段不存在，并验证 `message`/`diagnostics` 不作为稳定分类。
- Failure normalization matrix：覆盖 cancellation、timeout、network、invalid request/configuration、carrier/library/bootstrap/dispatch unavailable、ABI/schema/internal、unknown native code 和 malformed payload。
- Cancellation state-machine tests：覆盖 cancel-before-execute、cancel-in-flight、response-wins、cancel-wins、重复 cancel、second execute和cancel-after-terminal。
- Native cancellation linearization tests：accepted cancel返回 `1` 且不 callback；成功dispatch且仍outstanding的request在Callback Commit先发生时cancel返回 `0` 且callback必须到达；unknown request返回 `0` 不承诺callback；`cancel → dispose → non-empty callback` 不提前关闭 callback handle。
- Response Body ownership tests：覆盖 adopted-view identity、非空 native `bytes()` exactly-one-copy、Dart-buffered/empty body零额外copy、`string()` direct decode、explicit close、decode error、second consumption 和 exactly-once release。
- Response Body performance regression：使用大 body fixture 或 copy instrumentation，断言 transport/mapper/public construction 没有中间完整 buffer copy。
- Request Body ownership/performance regression：断言 byte-backed construction 保持输入 identity、mapper/DTO 保持 identity、非空 dispatch 恰好一次 Dart-to-native copy、空 body零allocation/零copy、`Uint8List` text encoding 不额外复制，且 request-side `byteStream()` 已删除。
- Request encoder failure regression：非空 allocator返回null为 `internal`，copier不调用；copy抛错时native body release恰好一次；任何 pre-dispatch失败都不创建callback-outstanding pending entry。
- Response decoder ownership regression：error/empty result立即free一次，非空result在owner消费/close时free一次；empty status在free后仍保持原值；mapper在handoff前抛错必须release owner。
- Codegen freshness：运行 ffigen/build_runner 前后比较 checked-in generated file hash；`build_runner` 不得分析 `test/`。
- Package analyze/test：所有内部 import 已迁到新的 `lib/src/` 路径。
- Clean-host compile test：fixture 只 import `package:nexa_http/nexa_http.dart` 并覆盖正式 HTTP API。
- Legacy absence test：搜索旧 root binding path、`adoptResponseBodyBytes`、`RequestBody.bytes`、request instance `bytes()`、request `byteStream()`、`payloadBytes` 和 compatibility/deprecated wrappers 无残留。
- Release metadata test：breaking release 的 package version、CHANGELOG 和 release notes 明确列出删除项。

### 7. Wrong vs Correct

#### Wrong

```dart
@Deprecated('Internal; use bytes() instead.')
Uint8List get payloadBytes => _bytes;

export 'nexa_http_bindings_generated.dart';
```

#### Correct

```dart
final payload = Uint8List.fromList(<int>[1, 2, 3]);
final body = RequestBody.takeBytes(payload);
// Ownership belongs to body now; do not mutate payload.
// Dispatch copies this canonical buffer into FFI-owned memory exactly once.
```

#### Wrong: cancellation result 与 callback lifetime 分离

```dart
completeCanceled();
pending.remove(requestId);
nativeCancel(clientId, requestId); // 返回值被忽略，callback 可能仍在路上。
```

#### Correct: 同一 handshake 决定 winner

```dart
final accepted = nativeCancel(clientId, requestId) == 1;
if (accepted) {
  completeCanceledAndRemove(requestId); // ABI 保证不会再 callback。
} else {
  keepPendingUntilCommittedCallback(requestId);
}
```

#### Wrong: pre-dispatch failure留下 pending entry

```dart
final completer = pending.register(requestId);
final encoded = encodeRequest(request); // allocator/copy可能在这里抛错。
```

#### Correct: encode成功后才声明callback-outstanding

```dart
final encoded = encodeRequest(request);
final completer = pending.register(requestId);
```

#### Wrong: free后继续读取FFI struct

```dart
releaseBinaryResult(resultPointer);
return TransportResponse(statusCode: resultPointer.ref.status_code);
```

#### Correct: 先snapshot标量，再转移或释放ownership

```dart
final statusCode = resultPointer.ref.status_code;
releaseBinaryResult(resultPointer);
return TransportResponse(statusCode: statusCode);
```
