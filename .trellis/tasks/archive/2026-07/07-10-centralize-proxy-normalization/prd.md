# Centralize proxy normalization

## Goal

在不改变平台 `proxy source` 所有权、proxy 行为或 Flutter SDK 集成面的前提下，把 core env、Android、Windows 和 Apple parser 重复的纯 proxy normalization 规则收敛到 `nexa_http_native_core` 的共享 primitives，并用同一组测试 fixture 锁定跨平台语义。

## Background

- ADR-0004 明确 `platform FFI crate` 独占 OS discovery/runtime state，core 可以拥有 shared proxy normalization（`docs/adr/0004-platform-owned-proxy-runtime-state.md:17-26,30-33`）。
- 相同的 URL normalization 当前存在于 core env、Apple parser、Android 和 Windows 四条路径（`native/nexa_http_native_core/src/platform/proxy.rs:316-328`、`native/nexa_http_native_apple_proxy/src/lib.rs:65-77`、`packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/proxy_source.rs:115-127`、`packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/proxy_source.rs:107-119`）。
- `,`、`;`、`|` bypass 拆分存在于 core env、Android 和 Windows（`native/nexa_http_native_core/src/platform/proxy.rs:330-337`、Android `proxy_source.rs:91-98`、Windows `proxy_source.rs:87-94`）；Apple exceptions 已由 SystemConfiguration 作为逐项数组提供，不经过该拆分规则。
- bypass trim、ASCII lowercase、去重和排序存在于 core、Apple、Android 和 Windows（core `proxy.rs:283-292`、Apple `lib.rs:42-50`、Android `proxy_source.rs:80-89`、Windows `proxy_source.rs:96-105`）。
- core env、Apple 和 Android `getprop` 具有相同的首尾空白/单双引号清洗逻辑（core `proxy.rs:301-314`、Apple `lib.rs:79-91`、Android `proxy_source.rs:100-113`）；Windows 当前不做引号清洗，该差异必须保留。
- Apple 的 `url`、Android/Windows 的 direct `reqwest` 依赖只服务上述重复 URL helper；core 的 `reqwest` 仍被 HTTP runtime、proxy application 和 URL selection 使用，不能删除。

## Dependencies

- 以已发布并通过四平台验证的 `v2.0.1` 为行为基线。
- 与 `07-10-decompose-rust-executor` 无强制顺序；实现开始前重新检查重叠文件，若对方已移动 `platform/proxy.rs` 或相关 runtime source，先回到规划更新文件清单。

## Requirements

### R1. Preserve ownership boundaries

- Android 保留 `getprop` discovery、默认端口和 `with_port` 语法。
- Windows 保留 registry discovery、`ProxyServer` grammar 和 construction-boundary refresh。
- iOS/macOS 保留 SystemConfiguration/CoreFoundation mapping；`nexa_http_native_apple_proxy` 保留 Apple entry/default-scheme/positive-port/`<local>` 组合。
- Core 不调用任何 OS API，不拥有 platform refresh policy。

### R2. One shared primitive contract

Core 必须成为以下纯规则的唯一生产实现：

- value cleanup：去首尾空白，再去首尾单双引号，再去空白；空结果为 `None`。
- URL normalization：无 scheme 时补调用方提供的 default scheme；只接受 `http`、`https`、`socks4`、`socks4a`、`socks5`、`socks5h`；返回 URL parser 的 canonical string，无效或不支持时为 `None`。
- bypass splitting：只按 `,`、`;`、`|` 拆分，trim 并丢弃空 token，不改变大小写或引号。
- bypass canonicalization：对已分词规则 trim、丢空、ASCII lowercase、去重并按字典序排序；不得隐式拆分或去引号。

### R3. Preserve path-specific semantics

- Core env、Apple 和 Android `getprop` 调用共享 value cleanup；Windows 不调用它。
- Core env、Android 和 Windows 的字符串列表调用 shared splitter；Apple exception item 保持原子值，即使内容含 `,`、`;` 或 `|`。
- Apple exception 先做 value cleanup，再 canonicalize；Windows bypass 中的引号按当前行为保留。
- Empty settings 继续表示 direct；单个 invalid proxy entry 继续降级为 `None`，不得影响同一 snapshot 的其他有效字段。

### R4. Clean cutover

- Core env 和全部 adapter/parser 直接调用共享 primitives。
- 删除重复 helper，不保留 forwarding wrapper、alias、兼容分支或双轨规则。
- 删除 Apple 的 direct `url` 与 Android/Windows 的 direct `reqwest` dependency；不得声称或尝试从最终平台库移除 core 所需的 `reqwest`。

### R5. Shared test fixtures

- 在 core 测试目录维护一份 test-only fixture source，覆盖 cleanup、全部支持 scheme、default scheme、malformed/unsupported URL、bypass separators、case/whitespace/duplicate ordering、quote preservation、empty/direct 和 invalid-entry isolation。
- Core、Apple parser、Android adapter 和 Windows adapter tests 读取同一 fixture source；不得为 fixture 增加 production API、feature flag 或 host-visible package。
- iOS/macOS tests 继续验证 adapter delegation 和 refresh boundary，不复制 primitive 的 exhaustive matrix。

### R6. Documentation and compatibility

- 更新受影响 Trellis specs，使 core ownership、Apple parser responsibility 和 platform adapter responsibility 与实现一致。
- 不改变 Rust `ProxySettings` shape、`ProxyConfigSource`、`PlatformRuntimeState`、public Dart API、C ABI、native artifact name/contents contract、carrier hook、target matrix 或 release workflow。

## Acceptance Criteria

- [x] AC1 (`R2`, `R5`): core 暴露四个窄的 internal Rust primitives，并由共享 fixture 完整覆盖。
- [x] AC2 (`R2`, `R4`): core env、Apple、Android、Windows 全部直接消费共享实现；搜索不到重复 URL/split/canonicalize/cleanup helper 或 forwarding wrapper。
- [x] AC3 (`R1`, `R3`): OS discovery、platform grammar、refresh policy 和 Apple-specific mapping 留在原 owner；Apple exception 不被拆分，Windows quote 语义不变。
- [x] AC4 (`R3`, `R5`): shared fixture 和 adapter tests 证明 URL、bypass、empty/direct、invalid-entry isolation 的输出与基线一致。
- [x] AC5 (`R4`): Apple `url`、Android/Windows direct `reqwest` dependency 删除，core `reqwest` 保留。
- [x] AC6 (`R6`): core、Apple parser、Android、Windows、iOS、macOS focused tests 以及 workspace Rust tests 通过。
- [x] AC7 (`R6`): public API/ABI、runtime refresh、artifact、Flutter carrier 和 release 文件无变更。
- [x] AC8 (`R6`): core、Apple、Android、Windows 和 shared layering specs 准确记录新的 ownership。

## Out of Scope

- 新增或修改 public proxy configuration API。
- 扩展支持的 scheme、bypass grammar 或平台集合。
- 改变 polling/construction-boundary refresh policy、env precedence 或 proxy matching 行为。
- 合并 iOS/macOS SystemConfiguration adapter，或移动 Android `with_port` / Windows `ProxyServer` parser。
- 修改 artifact build、packaging、verification catalog 或 release transaction。
