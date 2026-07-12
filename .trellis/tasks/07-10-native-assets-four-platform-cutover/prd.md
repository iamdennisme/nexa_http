# Four-platform Native Assets clean cutover

## Goal

在一个原子子任务内让 Android、iOS、macOS、Windows 全部以 Flutter Native Assets/CodeAsset 作为唯一 native artifact packaging 与 runtime loading authority，并删除所有传统打包、固定路径 loader、影子产物和 fallback。

## Dependencies

- 依赖 `07-10-v2-public-http-api-cutover`，所有 runtime smoke 使用最终 v2 API。
- 依赖 `07-10-verification-catalog-ci-suites`，所有 target、ABI、artifact uniqueness 和 clean-host checks 注册到同一 Catalog。
- 本任务必须四平台整体完成；不得把单个平台完成状态作为可归档 child task 或可合并架构状态。

## Requirements

- `prepareNexaHttpNativeCarrierArtifact(...)` 返回的同一个 `File` 直接进入 `CodeAsset`；hook 不再忽略返回值或重新硬编码 packaged path。
- Canonical target matrix 唯一定义 target tuple、Rust target、source artifact、release filename、packaging identity 和 runner mapping。
- Runtime loader、ABI verifier、artifact uniqueness scan 和 clean-host smoke 指向同一个 target artifact identity，禁止“验证 A、运行 B”。
- 删除 CocoaPods resource bundle、carrier-owned `jniLibs` copy、CMake bundled-library copy、固定 bundle path、`DynamicLibrary.process()`/manual open shadow strategy 和所有 fallback branch。
- 删除 committed/materialized legacy native binaries及其生成/复制规则；App 每个 target 只能存在一个导出 canonical `nexa_http_*` ABI 的 payload。
- Workspace build 必须真正由请求 target tuple 驱动，不能用 host build 冒充 x64/arm64 等目标。
- Hook output/cache 以 target identity 隔离，避免并发 target 互删或覆盖；文件完成采用原子 materialization。
- 平台失败必须输出 stage、target tuple、SDK ref、expected action 和 underlying error，不得降级到另一路径。
- 旧代码、tests、docs、Podspec/Gradle/CMake 配置和 verification path 同任务删除或重写，不留“后续清理”。

## Acceptance Criteria

- [ ] Android、iOS、macOS、Windows 全部由 Native Assets/CodeAsset 打包并通过正式 runtime loader 调用。
- [ ] 每个支持 target 的 build output 仅存在一个 canonical ABI payload；macOS 不再包含两份约 15 MB native library。
- [x] 所有传统 packaging、fixed-path/manual loader、fallback、legacy binaries 和相关测试/文档均不存在。
- [x] Target matrix tests 证明每个 tuple 驱动正确 Rust target、source file、asset identity 和 runner。
- [ ] 最终 CodeAsset 对每个 target 通过 exact ABI missing/unexpected comparison。
- [ ] 四个平台 clean host 实际完成 plugin registration、Native Asset loading、FFI client creation、fixture HTTP request、callback 和 body release。
- [x] 并发/重复/多架构 build 隔离测试通过，没有共享目录删除竞态。
- [x] Catalog 的 integration/candidate checks 只消费最终 Native Asset identity。

## Verification status

- 本机 Apple blocking row 已通过：`.dart_tool/verification/reports/apple-macos.json` 为 schema v2、`status=passed`，覆盖 5 个 prepared targets、iOS/macOS 各 1 个最终 payload 和两次完整 runtime lifecycle proof。
- Apple prepared/package raw SHA 因 Xcode install-name rewrite 与 codesign 不同；两端 raw SHA 均保留，Mach-O `LC_UUID` 集合派生的 `identity_sha256` 一致。
- Android 与 Windows clean-host runtime proof 必须由 `.github/workflows/ci.yml` 的动态 `android-linux` / `windows-x64` blocking rows 完成；未取得对应 schema v2 report 前，本任务保持 `in_progress`，不得把平台缺失当作 pass 或归档任务。

## Out of Scope

- 创建公开 tag 或 GitHub Release。
- 与外部契约无关的 Dart transport/Rust executor/proxy 内部重构。
