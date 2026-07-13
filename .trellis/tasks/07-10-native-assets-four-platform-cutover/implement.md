# Four-platform Native Assets clean cutover — Implementation Plan

## 1. Preconditions

- 读取：
  - `docs/adr/0005-native-assets-authoritative-artifact-path.md`
  - `docs/contexts/artifact-integration/CONTEXT.md`
  - `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
  - `.trellis/spec/guides/project-layering-contract.md`
  - `.trellis/spec/guides/verification-command-contract.md`
  - `.trellis/spec/guides/tdd-development-policy.md`
- 使用FVM Flutter 3.41.5 / Dart 3.11.3。
- 每次一个RED → 最小GREEN → REFACTOR。
- 禁止fallback、deprecated alias、forwarder、legacy loader和双轨中间态。

## 2. Ordered TDD slices

### Slice 1 — Hook returned-File identity

1. RED：四个平台hook注入fake preparation，返回非默认File；断言`CodeAsset.file`就是该File URI。
2. GREEN：hook保存返回值并只调用`resolveFromFile`。
3. RED：source contract拒绝asset bundle拥有`resolve(BuildInput)`和legacy `jniLibs/Frameworks/Libraries`路径。
4. GREEN/REFACTOR：四个平台asset bundle收敛为File→CodeAsset deep adapter，共享logical asset name常量。

### Slice 2 — Canonical target and asset identity

1. RED：literal 9-tuple contract逐项固定OS/arch/SDK/Rust triple/source filename/release filename/build script/runner/native asset logical name。
2. GREEN：深化target matrix并从Catalog projection消费runner/build fields。
3. RED：任意两个不同tuple不得映射同一materialization destination。
4. GREEN：删除`packagedRelativePath/packagedDirectoryRelativePath`，新增target-keyed output resolver。

### Slice 3 — Carrier-owned `@Native` bindings

按一个carrier一个垂直切片推进：Android → iOS → macOS → Windows。

每个平台：

1. RED：generated binding的`@DefaultAsset`/`@Native` asset ID必须等于hook CodeAsset ID。
2. GREEN：用ffigen `ffi-native.assetId`生成carrier bindings/adapter。
3. RED：plugin不得包含`DynamicLibrary.open/process`、fixed path或library basename。
4. GREEN：plugin注册bindings factory；主包shared transport通过interface消费。
5. RED：重复同identity注册幂等、冲突identity注册失败。
6. GREEN：替换first-writer-wins registry。
7. REFACTOR：删除production dynamic library runtime/factory；测试改用fake bindings interface。

### Slice 4 — Target-driven platform scripts

1. RED：每个script拒绝缺`--target`/`--output-dir`，unknown target失败。
2. GREEN：统一typed CLI parser/helper。
3. RED：macOS x64请求必须执行`--target x86_64-apple-darwin`，arm64同理。
4. GREEN：macOS不再host-only build。
5. RED：Android/iOS单tuple请求不得构建同平台其他targets。
6. GREEN：脚本只循环显式targets；Catalog group一次传全部group targets。
7. RED：script output不得位于carrier legacy directories。
8. GREEN：输出到显式target-keyed output root。

### Slice 5 — Atomic target-isolated materialization

1. RED：不同tuple并发prepare，结果路径不同且内容不覆盖。
2. GREEN：workspace使用repo级共享fingerprint cache，release/candidate使用hook-output target-keyed destination；删除platform broad directory cleanup。
3. RED：同tuple并发只触发一次producer。
4. GREEN：target lock/single-flight。
5. RED：candidate/release copy失败时旧完整destination保留，temp不残留。
6. GREEN：unique temp + digest verification + atomic replace；禁止先删destination。
7. RED：已存在且digest一致不重复copy/build/download。
8. GREEN：fast path并加入invocation counters。

### Slice 6 — Delete traditional platform packaging

逐平台用absence test先RED：

1. Android：删除Gradle Rust build/ABI/jniLibs/fallback与`NEXA_HTTP_ANDROID_FORCE_SOURCE_BUILD`。
2. iOS：删除`Frameworks` preserve path/materialization。
3. macOS：删除`Libraries`、resource bundle和fixed bundle loader。
4. Windows：删除`Libraries`和CMake bundled library。
5. 删除legacy `.gitkeep`、`.gitignore`规则、materialize_distribution required paths、demo/test fallback candidates。
6. 全仓absence search无legacy path/manual loader/fallback残留。

### Slice 7 — Artifact uniqueness and shared verification identity

1. RED：App bundle fixture含0/2 canonical ABI payload失败，1个返回path+digest。
2. GREEN：实现platform bundle scanner + exact symbol probe。
3. RED：Catalog integration缺`artifact-uniqueness` check失败。
4. GREEN：build producer返回`VerifiedNativeArtifactIdentity`；ABI/uniqueness消费同一handles。
5. RED：prepared File、CodeAsset contract、ABI identity、bundle digest任一不一致失败。
6. GREEN：统一identity comparison/reporting。

### Slice 8 — Four-platform clean-host runtime proof

1. RED：runtime fixture必须通过carrier `@Native` binding执行真实request；manual loader source contract为absence。
2. GREEN：保持v2 public API fixture，验证callback、body string consume、client close/exit。
3. RED：Android/iOS/macOS/Windows report缺payload uniqueness或runtime proof任一字段失败。
4. GREEN：扩展Catalog report/aggregate identity fields；Android使用non-resident启动，成功fixture保持存活，并在清空后的同device filtered logcat中有界轮询marker。
5. 在macOS本机执行Apple integration；Android/Windows由Actions blocking rows执行。

### Slice 9 — Documentation and final absence

1. 更新README、verification playbook、ADR/spec、package docs只描述Native Assets authority。
2. 搜索并清零：`jniLibs` carrier copy、`Frameworks`/`Libraries` artifact path、resource bundle、`bundled_libraries`、manual`DynamicLibrary` production loader、force source build、fallback。
3. 确认没有兼容代码或“后续删除”注释。

## 3. Full validation gate

```bash
fvm dart format --output=none --set-exit-if-changed <changed Dart files>
fvm dart analyze
fvm dart test
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux
fvm dart run scripts/workspace_tools.dart matrix --suite verify-integration
fvm dart run scripts/workspace_tools.dart matrix --suite verify-release-candidate
```

本任务平台gate：

- Android：`verify-integration --execution android-linux`。
- Apple：`verify-integration --execution apple-macos`。
- Windows：`verify-integration --execution windows-x64`。

真实candidate Android/iOS/macOS/Windows rows属于后续`07-10-immutable-release-candidate-transaction`，必须消费同一immutable candidate set；本任务只验证其Catalog matrix与identity contract，不伪造尚未执行的candidate通过状态。

每个平台必须同时通过target build、exact ABI、artifact uniqueness、development path、clean-host runtime。

## 4. Rollback points

- 每个RED/GREEN保持测试可解释，但只在完整四平台clean cutover后提交。
- 任一平台仍需要traditional packaging/manual loader时不得提交兼容分支；返回本任务设计修复。
- rollback只能整体revert最终work commit。

## 5. Debug retrospective — Android runtime marker delivery

- 根因分类：跨层契约与隐含假设。fixture生产marker，Flutter CLI/log bridge传输marker，verification消费marker；原实现把“等待2秒”误当成日志已被消费的确认。
- 失败原因：第一次修复只扩大了producer退出前的flush窗口，没有建立consumer acknowledgment；API 35 runner高CPU与system ANR时固定窗口仍会失效。
- 防复发机制：Android成功fixture不主动退出；runner使用non-resident启动和filtered logcat最多30秒有界轮询，先观测唯一完整marker再结束并清理fixture；回归测试覆盖延迟到达、零marker和重复marker。
- 系统性结论：异步proof传递不得用固定sleep代替acknowledgment；退出码、App启动和DDS连接均不能替代业务lifecycle marker。
- CI性能结论：Android三target Cargo build不得与高负载emulator竞争CPU。Actions使用`aosp_atd`，并在`pre-emulator-launch-script`通过Catalog预热共享fingerprint cache；正式suite仍是唯一gate且不得重复native build/copy。
