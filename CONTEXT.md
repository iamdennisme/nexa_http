# nexa_http Domain Context

本文档是当前架构讨论和架构 review 的领域词汇表。Canonical term 使用英文，以便和代码、package 名、module 名稳定对应；解释使用中文。

状态说明：

- confirmed：仓库 README、Trellis spec、测试或当前代码能确认。
- inferred：从多个来源推断，当前可用但后续可能细化。
- needs-owner-decision：需要项目 owner 后续确认。

## public Dart SDK

状态：confirmed

宿主 App runtime 代码直接使用的 Dart API surface，对应 `packages/nexa_http` 和入口 `package:nexa_http/nexa_http.dart`。

Owns:

- App-facing HTTP object model：`NexaHttpClient`、`NexaHttpClientBuilder`、`Request`、`RequestBuilder`、`Call`、`Response`、`ResponseBody`、`Headers`、`MediaType`、`Callback`、`NexaHttpException`。
- OkHttp-style request/call/response mental model。
- 对宿主 App 暴露的错误语义。

Does not own:

- Platform carrier registration details。
- Native artifact download、verification、packaging。
- Rust transport core runtime logic。
- Platform proxy discovery。

Relationships:

- 通过 internal native bridge 使用 `native transport`。
- 宿主 App 只 import `package:nexa_http/nexa_http.dart`。
- 宿主 App 依赖声明需要同时列出 `public Dart SDK` 和目标 `platform carrier`。

Evidence:

- `README.md`
- `README.zh-CN.md`
- `packages/nexa_http/README.md`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`

## host app

状态：confirmed

集成 `nexa_http` 的 Flutter 应用。

Owns:

- `pubspec.yaml` dependency declaration。
- 对 `public Dart SDK` 的 runtime 调用。
- 标准 Flutter `pub get` / `build` / `run` 流程。

Does not own:

- Native project 手工改造。
- 手动复制 native artifact。
- 手动注册 plugin。
- SDK 内部 package 结构或 artifact resolver。

Relationships:

- 依赖 `public Dart SDK`。
- 按目标平台显式依赖一个或多个 `platform carrier`。
- 通过 clean-host acceptance 验证集成路径。

Evidence:

- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
- `docs/verification-playbook.md`

## platform carrier

状态：confirmed

目标平台对应的 Flutter carrier package：`nexa_http_native_android`、`nexa_http_native_ios`、`nexa_http_native_macos`、`nexa_http_native_windows`。

Owns:

- Platform-specific native artifact packaging。
- Flutter plugin registration。
- Build hook integration。
- Platform runtime loader registration。

Does not own:

- Public runtime HTTP API。
- Shared HTTP execution logic。
- Cross-platform FFI request/response semantics。

Relationships:

- 宿主 App 显式声明目标平台需要的 carrier dependency。
- 使用 `nexa_http_native_internal` 协作处理 loading、target matrix、release artifact materialization。
- 包含对应的 `platform FFI crate`。

Evidence:

- `packages/nexa_http_native_android/README.md`
- `packages/nexa_http_native_ios/README.md`
- `packages/nexa_http_native_macos/README.md`
- `packages/nexa_http_native_windows/README.md`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`

## nexa_http_native_internal

状态：confirmed

内部 Dart 协作包，承载 runtime/loading、platform registry、native target matrix、release artifact materialization 和 consumer verification helpers。

Owns:

- Native library loading abstraction。
- Platform runtime registry。
- Native target matrix。
- Release artifact manifest parsing、download、checksum verification、packaging destination。
- Workspace package/source-build detection helpers。

Does not own:

- App-facing HTTP API。
- Platform-specific Rust proxy discovery。
- Rust HTTP execution runtime。

Relationships:

- 被 `public Dart SDK` 和 `platform carrier` 内部使用。
- 不应被宿主 App runtime 示例直接 import。

Evidence:

- `packages/nexa_http_native_internal/lib/src/native/`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`

## native transport

状态：confirmed

从 Dart request/call execution 到 Rust HTTP execution 的 FFI-backed transport path。

Owns:

- Dart request/config 到 native DTO/FFI args 的映射。
- Dynamic library loading handoff。
- FFI request dispatch。
- Native callback result decoding。
- Native-owned response body adoption。
- Cancellation handoff。

Does not own:

- Public HTTP object semantics beyond mapping。
- Platform-specific proxy source implementation。
- Artifact packaging。

Relationships:

- `public Dart SDK` 通过它执行请求。
- 它通过 `uniform C ABI` 调用 `Rust transport core`。
- 它依赖 `platform carrier` 注册的 native runtime loader。

Evidence:

- `packages/nexa_http/lib/src/client/`
- `packages/nexa_http/lib/src/data/sources/`
- `packages/nexa_http/lib/src/native_bridge/`

## Rust transport core

状态：confirmed

共享 Rust crate `native/nexa_http_native_core`。它为所有平台 FFI crate 提供 HTTP runtime、FFI 数据结构、proxy abstraction 和错误模型。

Owns:

- Shared HTTP execution runtime。
- FFI-visible request/response/error data structures。
- Client registry、request dispatch、cancellation、callback、result free。
- Shared proxy matching、env fallback、request-time proxy application。
- Abstract platform state contracts。

Does not own:

- OS-specific proxy discovery。
- Platform dynamic library packaging。
- Workspace/pub-cache/artifact probing。
- Host app integration instructions。

Relationships:

- 被 `platform FFI crate` 包装成平台动态库。
- 通过 `uniform C ABI` 暴露给 Dart native transport。
- 消费来自平台的 `platform runtime state`。

Evidence:

- `native/nexa_http_native_core/src/`
- `.trellis/spec/nexa_http_native_core/backend/index.md`
- `.trellis/spec/nexa_http_native_core/backend/directory-structure.md`

## platform FFI crate

状态：confirmed

平台 Rust crate，位于 `packages/nexa_http_native_<platform>/native/nexa_http_native_<platform>_ffi`。

Owns:

- Platform dynamic library artifact。
- C ABI export glue for `nexa_http_*` symbols。
- Binding `Rust transport core` runtime to platform-specific proxy source。
- Platform-specific proxy settings discovery and parsing。

Does not own:

- Core request/response/runtime executor logic。
- Dart build hook or release artifact download。
- Host native project modification。

Relationships:

- 属于对应 `platform carrier`。
- 复用 `Rust transport core`。
- 产出 `native artifact`。

Evidence:

- `.trellis/spec/nexa_http_native_android_ffi/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_ios_ffi/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_macos_ffi/backend/directory-structure.md`
- `.trellis/spec/nexa_http_native_windows_ffi/backend/directory-structure.md`

## uniform C ABI

状态：confirmed

所有平台 native artifacts 对 Dart 暴露的统一 C ABI surface，例如 `nexa_http_client_create`、`nexa_http_client_execute_async`、`nexa_http_client_cancel_request`、`nexa_http_client_close`、`nexa_http_binary_result_free`。

Owns:

- Dart/Rust binary contract shape。
- Pointer/length ownership boundaries。
- Async callback entrypoint。
- Native result/free contract。

Does not own:

- Platform-specific request pipeline variants。
- Host app API。
- Artifact discovery。

Relationships:

- 由 `platform FFI crate` export。
- 由 Dart `native transport` call。
- Struct definitions live in `Rust transport core`。

Evidence:

- `native/nexa_http_native_core/src/api/ffi.rs`
- `native/nexa_http_native_core/include/nexa_http_native.h`
- `packages/nexa_http_native_*/native/*_ffi/src/lib.rs`

## proxy settings

状态：confirmed

描述系统代理配置的跨平台模型，包括 HTTP、HTTPS、all/SOCKS 和 bypass rules。

Owns:

- Effective proxy values consumed by Rust request execution。
- Bypass matching input。
- Platform/environment merge result。

Does not own:

- OS-specific discovery mechanism。
- Platform change-listening policy。

Relationships:

- 由 `platform FFI crate` 从 OS-specific source 读取。
- 通过 `platform runtime state` 暴露给 `Rust transport core`。
- 由 `Rust transport core` 应用到 reqwest client。

Evidence:

- `native/nexa_http_native_core/src/platform/proxy.rs`
- `native/nexa_http_native_core/src/platform/source.rs`
- `packages/nexa_http_native_*/native/*_ffi/src/proxy_source.rs`

## platform runtime state

状态：confirmed

平台侧提供给 Rust core 的当前 runtime state，当前主要承载 proxy snapshot、generation 和 refresh policy。

Owns:

- Current proxy snapshot。
- Proxy generation。
- Refresh mode / platform-specific update policy。

Does not own:

- HTTP client registry。
- Request execution。
- Dart public API。

Relationships:

- 由 `platform FFI crate` 提供 source。
- 被 `Rust transport core` 读取并用于 client construction/rebuild decisions。

Evidence:

- `native/nexa_http_native_core/src/runtime/managed_proxy_state.rs`
- `native/nexa_http_native_core/src/platform/source.rs`
- `.trellis/spec/nexa_http_native_core/backend/directory-structure.md`

## native artifact

状态：confirmed

最终被 Flutter build/run 打包或加载的平台 native binary，例如 Android `.so`、iOS/macOS `.dylib`、Windows `.dll`。

Owns:

- Platform-specific compiled Rust output。
- Runtime native library loaded by `platform carrier`。

Does not own:

- Release manifest metadata。
- Host app configuration policy。

Relationships:

- 由 `platform FFI crate` build。
- 由 `platform carrier` package/build hook materialize and package。
- 作为 `release artifact` 发布或作为 workspace debug artifact 使用。

Evidence:

- `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_target_matrix.dart`
- `docs/verification-playbook.md`

## release artifact

状态：confirmed

发布到 release assets、供 git/tag consumer 或 release consumer 路径下载和校验的 native artifact 文件及 manifest entry。

Owns:

- Release asset file name。
- SHA-256 checksum。
- Source URL。
- Target OS / architecture / SDK metadata。

Does not own:

- Runtime public API。
- Platform proxy behavior。

Relationships:

- 对应一个 `native artifact`。
- 由 `nexa_http_native_internal` materialize 到 `platform carrier` package layout。
- 由 clean release consumer verification 验证。

Evidence:

- `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_target_matrix.dart`
- `packages/nexa_http_native_internal/lib/src/native/nexa_http_native_release_consumer.dart`
- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`

## clean-host consumer

状态：confirmed

从干净 Flutter App 验证 SDK 集成的 consumer path。它证明宿主只通过 package dependency、public Dart API 和标准 Flutter build/run 即可使用 SDK。

Owns:

- Integration acceptance signal。
- Host-facing packaging/runtime registration verification。

Does not own:

- SDK internal workaround。
- Manual native project modification。

Relationships:

- 使用 `public Dart SDK` 和目标 `platform carrier` dependencies。
- 验证 `native artifact` packaging 和 plugin registration。
- 是 release gate 的核心证据。

Evidence:

- `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
- `docs/verification-playbook.md`
- `scripts/workspace_tools.dart`

## architecture review

状态：inferred

面向代码库结构的 deepening 分析，用 module、interface、implementation、depth、seam、adapter、leverage、locality 等术语描述候选重构。

Owns:

- 发现 shallow module 和低 locality 的结构性摩擦。
- 基于 `CONTEXT.md` 词汇命名候选。
- 对照 `docs/adr/` 标记不应重开的决策。

Does not own:

- 直接改变 public API、ABI、package layout 或 runtime behavior。
- 取代 ADR 或 PRD。

Relationships:

- 读取 `CONTEXT.md` 作为领域语言。
- 读取 `docs/adr/` 避免重复挑战已接受决策。
- 输出 HTML report 供后续选择候选并进入设计深挖。

Evidence:

- `.agents/skills/improve-codebase-architecture/SKILL.md`
