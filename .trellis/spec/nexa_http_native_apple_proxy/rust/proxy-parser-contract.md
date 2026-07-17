# Apple proxy parser 契约

## Scenario: iOS/macOS 共用纯解析器

### 1. Scope / Trigger

- Trigger：修改 `native/nexa_http_native_apple_proxy`、iOS/macOS `proxy_source.rs` 的原始值映射，或 Apple proxy 字段解析规则。
- 本契约只覆盖 Apple SystemConfiguration 值到 `ProxySettings` 的纯转换，不覆盖系统 API 调用、proxy refresh、C ABI、artifact packaging 或 Flutter host integration。

### 2. Signatures

```rust
pub struct AppleProxyEntry {
    pub enabled: bool,
    pub host: Option<String>,
    pub port: Option<i32>,
}

pub struct AppleProxySettings {
    pub http: AppleProxyEntry,
    pub https: AppleProxyEntry,
    pub socks: AppleProxyEntry,
    pub exceptions: Vec<String>,
    pub exclude_simple_hostnames: bool,
}

pub fn parse_apple_proxy_settings(
    input: AppleProxySettings,
) -> nexa_http_native_core::platform::ProxySettings;
```

### 3. Contracts

- iOS/macOS FFI crate 负责调用 `SCDynamicStoreCopyProxies`、读取 CoreFoundation dictionary，并构造 `AppleProxySettings`。
- 本 crate 不依赖 CoreFoundation/SystemConfiguration；它只依赖 `nexa_http_native_core` 的 `ProxySettings` 和 shared proxy normalization primitives。
- `http` 与 `https` 缺省 scheme 都是 `http`；`socks` 缺省 scheme 是 `socks5`，输出到 `ProxySettings::all`。
- 只接受 `http`、`https`、`socks4`、`socks4a`、`socks5`、`socks5h` scheme。
- host 与 exceptions 在解析前通过 core `clean_proxy_value` 去除首尾空白和单双引号；空值被忽略。
- 端口只有大于零时才拼接；超出 URL 合法范围的值由 URL parser 判为无效。
- 已清洗的 bypass items 通过 core `canonicalize_bypass_rules` 转为 ASCII 小写、去重并按字典序排序；`exclude_simple_hostnames=true` 时加入 `<local>`。Apple exceptions 是数组 item，不经过 delimited splitter。
- 返回值不产生 error/log；单个无效 proxy 条目降级为 `None`，不影响其他字段。
- 共享 crate 静态链接进既有 iOS/macOS 动态库，不新增 host dependency、plugin、release artifact 或正式配置。

### 4. Validation & Error Matrix

| 输入条件 | 输出/处理 |
|----------|-----------|
| `enabled=false` | 对应 proxy 字段为 `None` |
| host 缺失、空白或仅有引号 | 对应 proxy 字段为 `None` |
| host 无 scheme | 按 HTTP/HTTPS/SOCKS 字段补默认 scheme |
| host 有受支持 scheme | 保留显式 scheme，并输出 URL parser 的规范化字符串 |
| host 有不支持 scheme 或 URL 无效 | 对应 proxy 字段为 `None` |
| `port <= 0` | 省略端口后继续解析 host |
| exception 空白 | 丢弃该项 |
| exception 重复或大小写不同 | 转小写后保留一项 |
| exception 内容含 `,`、`;` 或 `|` | 作为一个数组 item 保留，不拆分 |
| `exclude_simple_hostnames=true` | bypass 中包含 `<local>` |
| SystemConfiguration 返回 null | 由平台 FFI crate 返回 `ProxySettings::default()`，不调用本 parser |

### 5. Good/Base/Bad Cases

- Good：macOS adapter 读取 raw dictionary 值，构造 `AppleProxySettings`，调用一次 `parse_apple_proxy_settings()`。
- Base：所有 proxy 均 disabled 且 exceptions 为空，返回 `ProxySettings::default()`。
- Bad：在 iOS/macOS `proxy_source.rs` 各复制一份 `clean_value()`、URL scheme 白名单或 bypass 去重逻辑。
- Bad：把 `SCDynamicStoreCopyProxies` 或 CoreFoundation 类型移入共享 parser crate 或 `nexa_http_native_core`。

### 6. Tests Required

- `cargo test -p nexa_http_native_apple_proxy`：断言 HTTP/HTTPS/SOCKS 默认 scheme、disabled/blank、quoted host、无效 scheme、非正端口和 bypass canonicalization。
- 共享 fixture `native/nexa_http_native_core/tests/fixtures/proxy_normalization_cases.rs` 必须由 Apple parser test 读取；测试还需覆盖 atomic exception 和 invalid sibling isolation。
- `cargo test -p nexa_http_native_macos_ffi`：断言 macOS raw-value adapter wiring、runtime state 和 `RefreshMode::ConstructionBoundary`。
- `cargo test -p nexa_http_native_ios_ffi`：断言 iOS raw-value adapter wiring、runtime state 和 `RefreshMode::ConstructionBoundary`。
- `cargo test --workspace`：断言共享依赖未破坏 Android/Windows/core。
- Catalog `verify-integration` Apple execution row：断言新 crate 仍隐藏在既有动态库和标准 Flutter 构建链路后。

### 7. Wrong vs Correct

#### Wrong

```rust
// 平台 crate 私自拥有解析规则，iOS/macOS 会再次漂移。
fn normalize_proxy_url(raw_host: &str) -> Option<String> { /* duplicated */ }
```

#### Correct

```rust
// parser 只保留 Apple 字段组合，共享 core 拥有通用纯规则。
let settings = parse_apple_proxy_settings(AppleProxySettings {
    http: AppleProxyEntry {
        enabled: http_enabled,
        host: http_host,
        port: http_port,
    },
    ..AppleProxySettings::default()
});
```
