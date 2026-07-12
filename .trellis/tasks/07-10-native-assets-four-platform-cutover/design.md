# Four-platform Native Assets clean cutover — Design

## 1. Problem statement

当前四个平台虽然都生成 `CodeAsset`，但 hook 丢弃 artifact preparation 返回的 `File`，重新从 `jniLibs`、`Frameworks`、`Libraries` 固定路径发现文件；runtime 又分别通过 soname、`DynamicLibrary.process()`、CocoaPods resource bundle 路径或 DLL basename 打开另一条路径。结果是 packaging、ABI verification 和 runtime loading 没有共享同一 artifact identity。

本任务的最小正确机制是：`Target Tuple -> target-scoped materialization File -> CodeAsset ID -> carrier-owned @Native bindings -> shared Dart transport`。任何传统平台 copy、manual loader 或 fallback 都不再参与 production path。

## 2. Architectural decisions

### 2.1 Carrier-owned `@Native` bindings

每个平台 carrier 拥有与自身 CodeAsset ID 完全匹配的 generated `@Native` bindings：

| carrier | Native Asset ID |
|---|---|
| `nexa_http_native_android` | `package:nexa_http_native_android/src/native/nexa_http_native_ffi.dart` |
| `nexa_http_native_ios` | `package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart` |
| `nexa_http_native_macos` | `package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart` |
| `nexa_http_native_windows` | `package:nexa_http_native_windows/src/native/nexa_http_native_ffi.dart` |

Carrier plugin registration继续作为 federated plugin selection，但注册的是 immutable bindings factory/adapter，不再注册 `DynamicLibrary` opener或路径策略。主包 transport只消费共享bindings interface，不知道carrier package、asset file path或平台loader规则。

选择该方案而不是主包单一asset ID的原因：Flutter CodeAsset要求hook输出的package namespace属于包含该hook的package；四个carrier分别拥有hook，因此runtime annotation必须引用各carrier asset ID。不得伪造`package:nexa_http/...` ID，也不得通过 basename/manual path绕开asset graph。

### 2.2 One prepared File enters CodeAsset directly

四个hook统一执行：

```text
BuildInput target tuple
  -> prepareNexaHttpNativeCarrierArtifact(..., outputDirectory)
  -> File
  -> CodeAsset(file: file.uri, id: canonical carrier asset ID)
```

hook不得忽略返回值；asset bundle只保留`File -> CodeAsset` adapter，删除从`BuildInput`重新推导legacy path的`resolve()`。

### 2.3 Canonical target matrix owns identity, not carrier layout

`NexaHttpNativeTarget`继续唯一拥有：

- target OS / architecture / SDK
- Rust target triple
- Cargo source artifact filename
- published asset filename
- build script
- Native Asset logical name / identity suffix
- verification runner projection

删除`packagedRelativePath`与`packagedDirectoryRelativePath`这类传统carrier layout字段。物化路径由target identity和hook output root派生，不是公开package内容：

```text
<output-root>/<profile>/<target-os>/<target-arch>/<target-sdk-or-none>/<release-file-name>
```

macOS arm64/x64不得再共享同一个destination。

### 2.4 Target-driven build script contract

平台脚本接口统一为：

```text
build_native_<platform>.sh <debug|release> --output-dir <dir> --target <rust-triple> [--target <rust-triple>...]
```

- hook传一个requested target。
- Catalog integration build group一次调用脚本并传该group的全部canonical targets。
- 脚本只构建显式targets，不按host默认、不机械构建整个平台全集。
- 每个target产物写入output dir下target-keyed路径；脚本不得复制到carrier `jniLibs/Frameworks/Libraries`。
- architecture/target不匹配时失败，不允许host artifact冒充requested tuple。

### 2.5 Atomic, target-isolated materialization

workspace、candidate、published download三种source都汇聚到同一target destination contract：

1. target-keyed lock file，跨process exclusive lock。
2. 已存在且digest一致时直接返回，不重复build/download/copy。
3. 写入同目录唯一temp file；不得使用共享`.candidate.tmp`。
4. 完成streaming digest验证后atomic rename/replace。
5. 失败只清理本次temp，旧完整destination保持可读。

不得删除platform共享目录。不同tuple可并发；同一tuple single-flight。

### 2.6 Runtime registry and caching

Registry保存immutable `NexaHttpNativeBindingsFactory`：

- 同一identity重复注册幂等。
- 不同identity冲突注册立即失败，不能first-writer-wins静默忽略。
- 主包按registered asset identity lazy-create一次bindings/transport lease factory；不得每次client重复打开library或重复symbol lookup。
- 删除`NexaHttpNativeRuntime.open()`、`NexaHttpNativeLibraryFactory`和production `DynamicLibrary` loader。

测试可直接注入fake bindings，不得恢复production explicit-path loader。

## 3. Traditional path deletion map

### Android

- 删除Gradle内Rust build、ABI scan、`NEXA_HTTP_ANDROID_FORCE_SOURCE_BUILD`和`jniLibs.srcDirs` authority。
- 删除carrier `android/src/main/jniLibs`生成/复制规则与`.gitkeep`。
- 删除`DynamicLibrary.open('libnexa_http_native.so')`。

### iOS

- 删除`ios/Frameworks` materialization与podspec `preserve_paths`。
- 删除`DynamicLibrary.process()` loader。
- runtime只通过carrier asset ID的`@Native` functions解析symbols。

### macOS

- 删除`macos/Libraries`、podspec resource bundle/preserve path和固定framework/resource bundle loader。
- macOS脚本必须显式接收arm64/x64 Rust target，不再host-only build。
- 最终App bundle uniqueness check必须拒绝旧resource bundle副本。

### Windows

- 删除`windows/Libraries`与CMake `bundled_libraries` copy。
- 删除DLL basename manual loader。

## 4. Verification identity flow

Catalog run context新增`VerifiedNativeArtifactIdentity`：

```text
target tuple
native asset ID
absolute prepared file
streaming SHA-256
source identity (workspace/candidate)
```

- native build producer返回该identity集合。
- ABI check直接消费这些File handles。
- hook/CodeAsset contract test证明`CodeAsset.file == prepared File.uri`且asset ID匹配carrier `@Native` binding。
- clean-host build返回App output；artifact uniqueness scanner证明每个target只有一个canonical ABI payload。
- runtime smoke成功必须走`@Native` bindings，并证明request、callback和body release。
- candidate ABI/runtime继续共享同一个`VerifiedCandidateSet`，不复制candidate set。

## 5. Artifact uniqueness scanner

按平台扫描最终App/APK distribution：

- Android：APK/解包后的目标ABI目录。
- iOS/macOS：`.app` bundle。
- Windows：runner distribution directory。

Scanner对candidate binary运行exact canonical symbol comparison，结果必须恰好一个payload：

- 0个：Native Asset未打包，失败。
- 1个：返回path+digest。
- 2个及以上：legacy duplicate/second authority，失败。

文件名匹配不足以证明identity；必须以canonical `nexa_http_*` exports识别payload。

## 6. Failure contract

所有build hook/materialization/verification失败至少包含：

```text
stage
target_os
target_architecture
target_sdk
rust_target
native_asset_id
sdk_ref/candidate_ref
expected_action
underlying_error
```

缺toolchain、target mismatch、lock/materialization失败、CodeAsset identity mismatch、payload count不为1均阻断；不得fallback到legacy path或skip-as-pass。

## 7. Performance contract

- Catalog integration每个平台build script每suite最多启动一次。
- hook按tuple构建，已存在且digest一致不重复build/copy。
- 同tuple并发coalesce；不同tuple不共享删除目录或temp名。
- candidate digest复用现有streaming cache；CodeAsset preparation只做Flutter build必须的一次materialization。
- bindings/runtime factory按isolate+asset identity lazy once，不重复`DynamicLibrary.open`或symbol lookup。

## 8. Rollout and rollback

本任务只有atomic clean cutover commit；不产生可合并的双轨阶段。rollback只能整体revert该commit，不恢复deprecated alias、manual loader、Gradle/Pod/CMake备用path。

四个平台任一真实clean-host row失败则任务不归档。当前macOS host可执行Apple rows；Android/Windows完整proof由Catalog CI对应runner完成。
