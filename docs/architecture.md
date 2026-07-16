# Architecture index

本页是 `nexa_http` 当前架构的导航与治理入口，不是新的决策来源。项目只有 Flutter SDK 层和原生 native 层；Platform Carrier、build hook、Native Asset、Release Candidate 和 clean-host verification 是两层内部或两层之间的机制。

## Domain contexts

领域词汇由 [`CONTEXT-MAP.md`](../CONTEXT-MAP.md) 和四个 bounded context glossary 维护：

| Context | Owns | Glossary |
| --- | --- | --- |
| HTTP API | Host App 使用的 client、request、call、response 和 HTTP Failure 语言 | [HTTP API](./contexts/http-api/CONTEXT.md) |
| Native Transport | Dart/native execution、cancellation、callback 和 memory ownership 语言 | [Native Transport](./contexts/native-transport/CONTEXT.md) |
| Platform Capability | Proxy Source、snapshot、generation 和 refresh policy 语言 | [Platform Capability](./contexts/platform-capability/CONTEXT.md) |
| Artifact Integration | Target Tuple、Platform Carrier、Native Asset、Release Gate 和 Verification Catalog 语言 | [Artifact Integration](./contexts/artifact-integration/CONTEXT.md) |

Glossary 只定义统一语言，不拥有架构选择或实现规则。

## Accepted decisions

| ADR | Status | Owned decision |
| --- | --- | --- |
| [ADR-0001](./adr/0001-public-dart-sdk-root-api.md) | Accepted | `package:nexa_http/nexa_http.dart` 是唯一宿主 runtime API |
| [ADR-0002](./adr/0002-explicit-platform-carrier-dependencies.md) | Accepted | 宿主显式声明目标平台 carrier dependency |
| [ADR-0003](./adr/0003-unified-async-ffi-transport.md) | Accepted | 四平台共用一条 async FFI request/callback pipeline |
| [ADR-0004](./adr/0004-platform-owned-proxy-runtime-state.md) | Accepted | 平台 FFI crate 拥有 OS Proxy Source，core 消费抽象 state |
| [ADR-0005](./adr/0005-native-assets-authoritative-artifact-path.md) | Accepted | Native Assets/CodeAsset 是唯一 packaging/loading authority |
| [ADR-0006](./adr/0006-response-body-single-consumption-ownership.md) | Accepted | Response Body 单次消费并确定性释放 native ownership |
| [ADR-0007](./adr/0007-request-body-transferred-ownership.md) | Accepted | `RequestBody.takeBytes` 显式转移 buffer ownership |
| [ADR-0008](./adr/0008-typed-public-http-failure-taxonomy.md) | Accepted | Public HTTP Failure 使用七值 typed taxonomy |
| [ADR-0009](./adr/0009-gated-immutable-release-transaction.md) | Accepted | 先验证 immutable candidate，再创建 public tag/Release |
| [ADR-0010](./adr/0010-verification-catalog-owns-gate-composition.md) | Accepted | Verification Catalog 独占 gate composition 与 matrix projection |

Accepted ADR 只能由后续 ADR 明确取代。编辑当前实现规则或操作文档不能静默改变 ADR 决策。

## Implementation ownership

Trellis package spec 把 ADR 转换成当前可执行约束。开始修改前通过 `get_context.py --mode packages` 选择真实 owner，再读取对应 index。

| Owner | Spec | Boundary |
| --- | --- | --- |
| Root workspace | [tooling](../.trellis/spec/nexa_http_workspace/tooling/index.md) | Verification Catalog、release transaction、root contracts 与文档治理 |
| Public Dart SDK | [dart](../.trellis/spec/nexa_http/dart/index.md) | HTTP API 与统一 Native Transport |
| Internal native helper | [dart](../.trellis/spec/nexa_http_native_internal/dart/index.md) | target matrix、artifact lifecycle 与 bindings registry |
| Android carrier | [flutter](../.trellis/spec/nexa_http_native_android/flutter/index.md) | Android hook adapter、plugin registration 与 bindings factory |
| iOS carrier | [flutter](../.trellis/spec/nexa_http_native_ios/flutter/index.md) | iOS hook adapter、plugin registration 与 bindings factory |
| macOS carrier | [flutter](../.trellis/spec/nexa_http_native_macos/flutter/index.md) | macOS hook adapter、plugin registration 与 bindings factory |
| Windows carrier | [flutter](../.trellis/spec/nexa_http_native_windows/flutter/index.md) | Windows hook adapter、plugin registration 与 bindings factory |
| Rust transport core | [rust](../.trellis/spec/nexa_http_native_core/rust/index.md) | shared runtime、C ABI、ownership、error 与 proxy abstraction |
| Apple proxy parser | [rust](../.trellis/spec/nexa_http_native_apple_proxy/rust/index.md) | iOS/macOS 共用的纯 proxy parser |
| Android FFI adapter | [rust](../.trellis/spec/nexa_http_native_android_ffi/rust/index.md) | Android Proxy Source 与 shared ABI wiring |
| iOS FFI adapter | [rust](../.trellis/spec/nexa_http_native_ios_ffi/rust/index.md) | iOS SystemConfiguration adapter 与 shared ABI wiring |
| macOS FFI adapter | [rust](../.trellis/spec/nexa_http_native_macos_ffi/rust/index.md) | macOS SystemConfiguration adapter 与 shared ABI wiring |
| Windows FFI adapter | [rust](../.trellis/spec/nexa_http_native_windows_ffi/rust/index.md) | Windows registry adapter 与 shared ABI wiring |

## Authority and supersession

发生冲突时按以下权威顺序处理：

1. Context glossary 拥有术语含义，但不决定架构。
2. Accepted ADR 拥有长期架构决策；只有后续 ADR 可以取代它。
3. Shared guide 与 package spec 拥有当前实现约束，必须落实 ADR 且跟随现有代码演进。
4. Root/package README 与 [verification playbook](./verification-playbook.md) 说明消费和操作方式，必须服从 ADR/spec。
5. Archived task artifact、review 记录和 commit 提供 provenance，不是当前 authority。

如果 README/playbook 与 spec 不一致，先按 ADR 判断正确 owner，再在同一变更中同步实现 spec 和操作文档。历史 artifact 保留原结论，只修复失效路径或明确标注已不存在的历史引用。

## Review provenance

当前索引基于 2026-07-16 的 source/spec/task audit，known-good 产品基线是 `v2.0.1`。

| Evidence | Reference |
| --- | --- |
| Domain model architecture review | [archived task](../.trellis/tasks/archive/2026-07/07-06-domain-model-architecture-review/design.md) |
| Architecture spec coverage review | [archived task](../.trellis/tasks/archive/2026-07/07-07-architecture-spec-coverage/design.md) |
| Verification Catalog cutover | [archived task](../.trellis/tasks/archive/2026-07/07-10-verification-catalog-ci-suites/design.md) |
| Four-platform Native Assets cutover | [archived task](../.trellis/tasks/archive/2026-07/07-10-native-assets-four-platform-cutover/design.md) |
| Public v2 API cutover | [archived task](../.trellis/tasks/archive/2026-07/07-10-v2-public-http-api-cutover/design.md) |
| Immutable release transaction | [archived task](../.trellis/tasks/archive/2026-07/07-10-immutable-release-candidate-transaction/design.md) |
| Current governance audit | [source audit](../.trellis/tasks/07-10-trellis-architecture-spec-governance/research/architecture-governance-audit.md) |

Key history is `95dad7a` (bounded-context language), `55dee2d` (four-platform integration proof), `90d55ec` (immutable release transaction), `dc5cd28` (pub-cache exact release ref), and tag commit `2bdfcce` (`v2.0.1`). The annotated `v2.0.1` tag records candidate `gha:29384993870:8331179239` with digest `7fcbe86664266b0b704a4c530367344a476f563700325f13f417e6fa77e44516`.

Use the [verification playbook](./verification-playbook.md) for executable commands. A later release becomes the known-good baseline only after its immutable candidate passes the four-platform Release Gate and its docs/spec metadata are synchronized.
