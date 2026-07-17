# 质量规范

## 必需检查

- Rust 代码必须通过 `cargo fmt --all --check`。
- core 行为变更必须跑 `cargo test -p nexa_http_native_core`；跨平台 proxy 变化还要跑对应 platform FFI crate 测试。
- FFI struct 或函数签名变化必须同步 Dart generated bindings、Dart decoder/mapper 和相关 tests。
- 请求 body ownership、response body ownership 和 `nexa_http_binary_result_free` 变化必须有回归测试。

## 必需模式

- 所有 C ABI function 使用 `#[unsafe(no_mangle)] extern "C"`。
- FFI pointer + len 输入必须在 Rust 侧显式校验 null/length 组合。
- Native-owned bytes 只能有一个释放入口；`NativeHttpOwnedBody::free_raw_parts` 是 response body ownership 的核心规则。
- Rust-visible raw-pointer release API 必须标记为 `unsafe` 并写 `# Safety`；导出的 `extern "C"` ABI symbol不变，但Rust函数类型必须如实表达调用前置条件。
- Proxy refresh 策略通过 `RefreshMode` 表达，平台 crate 实现 `ProxyConfigSource`。
- 测试 `ManagedProxyState` 保存的 raw snapshot 时使用 `current_proxy_snapshot()`；`current_platform_state()` 会合并进程级 proxy 环境变量，断言 view 内容时必须提供优先级更高的显式平台值或隔离 proxy 环境变量。

## 禁止模式

- 不要在 core crate 中复制 platform-specific proxy 读取逻辑。
- 不要在 runtime loader 或 executor 中搜索 workspace、pub-cache、release asset 或环境变量路径。
- 不要新增隐藏 fallback：缺 artifact、缺 runtime registration、缺 explicit input 时必须结构化失败。
- 不要为了让测试通过降低 FFI ownership 测试强度，例如只断言 callback 被调用但不验证 free。
- 不要通过 `#[allow(clippy::not_unsafe_ptr_arg_deref)]` 隐藏raw pointer contract；修正unsafe边界和测试调用点。

## 真实例子

- `native/nexa_http_native_core/tests/runtime_smoke.rs`：覆盖 FFI request、default headers、timeout、body 和 callback。
- `native/nexa_http_native_core/tests/managed_proxy_state.rs`：覆盖 construction-boundary 和 polling refresh 模式。
- `packages/nexa_http/test/ffi_nexa_http_native_data_source_test.dart`：Dart 侧验证 FFI config、request、response 和 cancellation contract。

## Scenario: Shared proxy normalization primitives

### 1. Scope / Trigger

- Trigger：修改 `platform/proxy_normalization.rs`、core env proxy fallback，或 Android/Windows/Apple adapter 的 shared normalization 调用。
- 该契约只覆盖纯值转换，不覆盖 OS discovery、platform grammar、refresh policy、proxy matching 或 C ABI。

### 2. Signatures

```rust
pub fn clean_proxy_value(value: &str) -> Option<String>;
pub fn normalize_proxy_url(value: &str, default_scheme: &str) -> Option<String>;
pub fn split_bypass_rules(value: &str) -> Vec<String>;
pub fn canonicalize_bypass_rules(rules: Vec<String>) -> Vec<String>;
```

### 3. Contracts

- cleanup 按既有顺序 trim、去首尾双引号、去首尾单引号、再 trim；空值返回 `None`。
- URL 无 scheme 时补 `default_scheme`；只接受 `http`、`https`、`socks4`、`socks4a`、`socks5`、`socks5h`，输出 parser canonical string。
- splitter 只处理 `,`、`;`、`|`，保留 token case/quotes；canonicalizer 只对已分词值做 trim、ASCII lowercase、去重、字典序排序。
- Apple exceptions 是已分项数组，不调用 splitter；Apple 先 cleanup 再 canonicalize。Windows 不调用 cleanup，以保留 registry quote 语义。
- primitives 无 OS I/O、日志、runtime state 或 C ABI side effect。

### 4. Validation & Error Matrix

- empty/blank cleanup -> `None`。
- unsupported scheme、malformed URL 或非法 port -> `None`，不影响同一 `ProxySettings` 的其他字段。
- delimited input -> 非空 trimmed tokens；empty separators 被丢弃。
- duplicate/case-variant rules -> 单个 lowercase item，结果按字典序排序。
- Apple item 含 `,;|` -> 作为一个 bypass rule 保留，不拆分。

### 5. Good/Base/Bad Cases

- Good：platform crate 处理自己的 host/port grammar 后直接调用 `normalize_proxy_url`。
- Base：core env、Android、Windows 使用 splitter 后一次 canonicalizer。
- Bad：在任一 adapter 复制 scheme allowlist、`BTreeSet` canonicalizer 或 quote cleanup。

### 6. Tests Required

- `native/nexa_http_native_core/tests/proxy_normalization.rs` 使用 `tests/fixtures/proxy_normalization_cases.rs` 覆盖 cleanup、全部 supported schemes、invalid URL、split 和 canonicalization。
- Apple/Android/Windows proxy tests 必须读取同一 fixture source，并覆盖 valid、empty/direct、invalid sibling；Apple 还需断言 atomic exception，Windows 需断言 quote preservation。
- `cargo test --workspace` 和受影响 crate strict Clippy 必须通过。

### 7. Wrong vs Correct

#### Wrong

```rust
fn normalize_proxy_url(value: &str, default_scheme: &str) -> Option<String> {
    // platform crate 私自复制 URL scheme allowlist
}
```

#### Correct

```rust
use nexa_http_native_core::platform::normalize_proxy_url;

let proxy = normalize_proxy_url(address, "http");
```

## Scenario: 统一平台 FFI 导出契约

### 1. Scope / Trigger

- Trigger: 修改 `nexa_http_*` public C ABI、`export_nexa_http_ffi!`、任一 platform FFI `src/lib.rs`、C header、Dart generated bindings 或 native artifact symbol verification。

### 2. Signatures

- 平台调用：

```rust
nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<PlatformProxySource>,
}
```

- 产物校验：Catalog `check native-abi`，显式传入 execution、fixture URL 与 device。
- canonical public symbols 位于 `scripts/native_abi_contract.dart`，必须与 `include/nexa_http_native.h` 和 generated Dart lookup 一致。

### 3. Contracts

- `ffi_exports.rs` 是九个 public wrapper 名称、签名和 delegation 的唯一 Rust 定义点。
- Platform FFI crate 继续拥有 `RUNTIME`、proxy source 和 `cdylib`；core 继续只产出 `rlib`。
- Android 保持 polling runtime；iOS/macOS/Windows 保持 construction-boundary runtime。
- `nexa_http_test_*` ownership helpers 可以继续存在于 production artifact，但不属于 public 九符号集合。
- Artifact verifier 必须把所有非 test `nexa_http_*` exports 与 public 集合做 exact comparison，不只检查 subset。
- Header 到 Dart bindings 通过 ffigen whitespace-insensitive semantic diff 检查；精确 symbol names 另由 source contract test 检查。

### 4. Validation & Error Matrix

- Packaged artifact 缺失 -> `StateError` 包含 `stage=native ABI verification`、platform/target/artifact、SDK version/ref、expected action 和 underlying error。
- 当前 runner 没有可用 symbol tool -> 尝试 platform fallbacks 后结构化失败，并列出每条 command error。
- 缺少 public symbol -> `missing=<symbols>`，阻断 CI。
- 出现额外非 test `nexa_http_*` symbol -> `unexpected=<symbols>`，阻断 CI。
- 只有 `nexa_http_test_*` 额外 symbol -> public ABI comparison 通过。
- ffigen 产生非空白 declaration diff -> Ubuntu CI 失败；formatter-only wrapping 不算 ABI drift。

### 5. Good/Base/Bad Cases

- Good: core macro 增加或修改 wrapper，同时更新 header、bindings contract tests，并由每个平台 runner 检查真实 artifact。
- Base: wrapper 不变，artifact 额外包含现有 `nexa_http_test_*` helpers，public comparison 仍精确通过。
- Bad: 在某个平台 `lib.rs` 手写 `#[unsafe(no_mangle)]` wrapper，或只把新 symbol 加到一个平台。
- Bad: symbol checker 只验证 `containsAll`，因此无法发现额外 public ABI。

### 6. Tests Required

- `fvm dart test test/native_ffi_abi_contract_test.dart test/native_abi_verifier_test.dart`
- `cargo fmt --all --check`
- `cargo test --workspace`
- 四个平台 FFI crate focused tests。
- macOS、Ubuntu、Windows runner 分别运行 Catalog `verify-integration` 对应 execution row；suite 内只 build 一次并复用给 ABI、development path 与 clean-host consumer。

### 7. Wrong vs Correct

#### Wrong

```rust
#[unsafe(no_mangle)]
pub extern "C" fn nexa_http_client_close(client_id: u64) {
    RUNTIME.close_client(client_id);
}
```

#### Correct

```rust
nexa_http_native_core::export_nexa_http_ffi! {
    runtime = RUNTIME,
    state = ManagedProxyState<PlatformProxySource>,
}
```

## Scenario: Cancellation acknowledgment 与 Callback Commit 线性化

### 1. Scope / Trigger

- Trigger: 修改 `NexaHttpRuntime::execute_async`、`cancel_request`、inflight request state、Dart pending registry、`NativeCallable` disposal 或 `nexa_http_client_cancel_request` 的返回值处理。

### 2. Signatures

- C ABI 签名保持：

```c
uint8_t nexa_http_client_cancel_request(uint64_t client_id, uint64_t request_id);
```

- 返回 `1`：cancel 在线性化点先于 Callback Commit，native 保证该 request 不再 callback。
- 返回 `0`：cancel 未被接受。仅当 `execute_async` 已返回 `1` 且 Dart registry 仍标记 callback-outstanding 时，`0` 才保证 Callback Commit 已发生并且 callback 必须到达；unknown/already-removed request ID 不承诺 callback。

### 3. Contracts

- cancel 与 completion 必须通过同一个 inflight state lock 决定 winner。
- Completion 必须先把 `Active` 变为 `CallbackCommitted`，再构造 FFI-owned binary result 和调用 callback。
- Cancel 看到 `Pending/Active` 时可以返回 `1`、抑制 callback并中止工作。
- Cancel 看到 `CallbackCommitted` 或已离开可取消状态时必须返回 `0`；callback delivery保证只适用于成功dispatch且仍outstanding的合法request。
- `CanceledPending` 在 abort handle 安装时被清理，不得 callback。
- Accepted cancel 后 Dart可以移除 callback-outstanding entry；cancel返回 `0` 时 Dart必须保留entry，直到callback完成ownership handoff/free。
- `NativeCallable` 只有在所有仍可能 callback 的entry清空后才能关闭。

### 4. Validation & Error Matrix

- cancel返回 `1` 后 callback仍被调用 -> ABI contract failure，可能触发closed callback handle。
- Callback Commit先发生但cancel返回 `1` -> terminal winner错误，Dart可能覆盖response。
- 成功dispatch且仍outstanding的request在cancel返回 `0` 后 callback未到达 -> pending registry永久不drain。
- 成功dispatch且仍outstanding的request在cancel返回 `0` 后，Dart提前完成canceled或删除entry -> callback result丢失或double free。
- dispatch返回 `0` -> 没有callback expectation，Dart立即移除entry并归一化为 `unavailable`。

### 5. Good/Base/Bad Cases

- Good: 合法outstanding request的completion在锁内提交 `CallbackCommitted`，cancel随后返回 `0`，Dart等待并交付response。
- Base: cancel在request仍Active时返回 `1`，abort work，Dart完成typed canceled且不等待callback。
- Bad: 先调用 `abort_handle.abort()` 并返回 `1`，但没有证明callback尚未开始。
- Bad: Dart对所有cancel保留tombstone，accepted cancel永不callback导致dispose永久等待。

### 6. Tests Required

- Rust unit: cancel先赢返回 `1` 且callback counter保持0。
- Rust unit: Callback Commit先赢的合法outstanding request在cancel返回 `0` 后callback恰好1次；unknown request返回 `0` 但无callback guarantee。
- Rust unit: `CanceledPending` 在handle安装后被移除且不callback。
- Dart registry: native cancel返回 `1` 时完成canceled并drain；返回 `0` 时保持callback outstanding。
- Dart FFI: `cancel → dispose → non-empty callback` 在返回 `0` 分支安全完成，result/body只释放一次。
- Call test: response-wins、cancel-wins、repeated cancel、pre-execute cancel、second execute和cancel-after-terminal。

### 7. Wrong vs Correct

#### Wrong

```rust
let handle = inflight.remove(&key);
handle.abort();
return 1; // callback 可能已经开始。
```

#### Correct

```rust
match inflight.get_mut(&key) {
    Some(InflightRequestState::Active(_)) => accept_cancel_and_suppress_callback(),
    Some(InflightRequestState::CallbackCommitted) => return 0,
    _ => return 0,
}
```
