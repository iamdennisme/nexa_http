# Centralize proxy normalization - Design

## Overview

本任务只加深纯 normalization 的共享实现，不合并 platform source。目标数据流是：

```text
OS/env raw value
  -> owning source/parser performs platform grammar and field mapping
  -> core proxy normalization primitives
  -> ProxySettings
  -> existing ManagedProxyState / reqwest application
```

`ProxySettings` 仍是边界模型；新增函数是 workspace-internal Rust API，不进入 C ABI 或 Dart API。

## Target Module

新增 `native/nexa_http_native_core/src/platform/proxy_normalization.rs`，并从 `platform/mod.rs` 重导出：

```rust
pub fn clean_proxy_value(value: &str) -> Option<String>;
pub fn normalize_proxy_url(value: &str, default_scheme: &str) -> Option<String>;
pub fn split_bypass_rules(value: &str) -> Vec<String>;
pub fn canonicalize_bypass_rules(rules: Vec<String>) -> Vec<String>;
```

这些函数保持无 OS I/O、无 logging、无 runtime state。返回 owned values，调用方可以直接组装 `ProxySettings`，不需要 wrapper。

`platform/proxy.rs` 继续拥有 env fallback、proxy selection、bypass matching 和 reqwest application，但它自身也必须调用上述模块，避免 core 内出现第二份私有规则。

## Primitive Contracts

| Primitive | Input boundary | Output | Explicit non-responsibility |
|---|---|---|---|
| `clean_proxy_value` | 一个可能带空白/首尾引号的 raw value | cleaned `String` 或 empty => `None` | 不解析 scheme、port 或 list separators |
| `normalize_proxy_url` | 已由 owner 组合好的 address + default scheme | supported canonical URL 或 `None` | 不 trim/去引号，不解释平台字段 |
| `split_bypass_rules` | env/Android/Windows 的 delimited string | trimmed non-empty tokens，保持 case/quotes | 不 lowercase、去重或处理 Apple array item |
| `canonicalize_bypass_rules` | 已 tokenized `Vec<String>` | trim + ASCII lowercase + sorted unique rules | 不拆分，不去引号，不做 bypass matching |

URL scheme allowlist 与现有四份实现完全相同。使用 core 已有 `reqwest::Url` parser，避免新增 parser dependency 或自写 URL 规则。

## Ownership by Path

### Core env fallback

`env_lookup` 负责环境变量优先级，依次调用 `clean_proxy_value`。`env_proxy_settings` 调用 shared URL/split/canonicalize primitives。Platform settings 优先于 env fallback、bypass merge 和 proxy matching 不变。

### Android

`AndroidProxySource` 和 `getprop` command 留在 FFI crate。`getprop` stdout 使用 shared cleanup；`with_port` 继续处理 Android host/port/default-port 规则；其结果调用 shared URL normalizer。两个 non-proxy properties 分别 split、合并后一次 canonicalize。

### Windows

Registry 读取、`ProxyEnable`、`ProxyServer` 的 `scheme=address` grammar、unsplit server 同时赋给 HTTP/HTTPS 的行为都留在 Windows crate。Address 只调用 URL normalizer，`ProxyOverride` 调用 splitter + canonicalizer。

Windows 路径不能调用 `clean_proxy_value`。现有代码只 trim registry strings；对 quoted server/bypass 做额外清洗会是行为变更。

### Apple parser and iOS/macOS

iOS/macOS FFI crates继续把 SystemConfiguration dictionary 映射成 `AppleProxySettings`，并保持 `ConstructionBoundary` refresh。Apple parser 继续拥有：

- enabled/disabled entry handling
- HTTP/HTTPS => `http`，SOCKS => `socks5` default scheme selection
- positive signed port composition
- SOCKS -> `ProxySettings::all`
- `exclude_simple_hostnames` -> `<local>`

Apple host 和每个 exception 先调用 shared cleanup；组合后的 host/port 调用 URL normalizer；已清洗的 exception vector 调用 canonicalizer。Apple exception 是 CFArray item，绝不调用 string splitter。

## Shared Fixture Design

Canonical fixture source 位于：

```text
native/nexa_http_native_core/tests/fixtures/proxy_normalization_cases.rs
```

它只定义 test structs/constants，不编译进 core production module。Core integration tests直接加载它；Apple/Android/Windows integration tests用 test-only `#[path = ...]` 引用同一文件，不增加 feature、公开测试 helper crate 或 production dependency。

Fixture 分为两层：

1. Primitive matrices：cleanup、URL scheme/default/invalid、bypass split、canonicalization 和 quote preservation。
2. Shared `ProxySettings` expectations：至少包含 valid HTTP+bypass、empty/direct、invalid HTTP plus valid sibling field，平台 tests 各自构造 raw OS shape 后断言同一 normalized expectation。

Adapter tests只补平台 grammar：Android default/explicit port、Windows `ProxyServer` mapping、Apple field mapping。它们不复制完整 scheme allowlist。

## Dependency Changes

- Keep `nexa_http_native_core -> reqwest`：core runtime 和 shared URL parser都需要它。
- Remove `nexa_http_native_apple_proxy -> url`：Apple 改用 core primitive。
- Remove Android FFI direct `reqwest`：其唯一使用是本地 `Url` helper。
- Remove Windows FFI direct `reqwest`：其唯一使用是本地 `Url` helper。

这是 direct dependency ownership cleanup，不会从最终 platform artifact 中移除经 core 静态链接的 `reqwest`。

## Compatibility and Migration

这是一次 clean cutover：core primitive tests 先建立，随后同一变更集中迁移所有 caller并删除本地 helper。不存在 deprecation、dual path 或数据迁移。

必须逐项保护的兼容点：

- HTTP URL canonical output 保留 trailing slash，SOCKS output遵循现有 URL parser output。
- Unsupported/malformed URL 仍返回 `None`，不会使整个 settings load 失败。
- Canonicalization 仍使用 ASCII lowercase 和 `BTreeSet` ordering。
- Apple cleanup order、`<local>` 和 atomic exceptions 不变。
- Windows quote behavior、Android port grammar、env precedence 不变。
- `ProxySettings::is_empty`、signature、snapshot validation 和 bypass matching 不变。

## Documentation Impact

实现确认后通过 `trellis-update-spec` 更新：

- core directory/quality specs：core owns shared proxy normalization。
- Apple parser contract：Apple owns field mapping but delegates generic cleanup/URL/bypass canonicalization。
- Android/Windows directory and quality specs：raw grammar remains local，generic rules来自 core。
- project layering contract：删除“Apple owns generic URL normalization/value cleanup/bypass canonicalization”的旧表述。

ADR-0004 不需要修改；本设计正是其已接受后果的落实。

## Risks and Rollback

- 最大风险是无意统一本来不同的 raw grammar。以 primitive 边界和 fixture case 防止 Apple splitting / Windows cleanup 漂移。
- 第二风险是 adapter tests只证明 happy path。shared invalid-entry isolation expectation 必须同时包含一个有效 sibling field，证明局部失败不会清空 snapshot。
- 若迁移出现任何 byte-for-byte output 差异，先停止并定位 fixture/调用顺序，不在本任务扩大为行为变更。
- 回滚是整体 revert 本任务；不保留 local helper 作为 fallback。
