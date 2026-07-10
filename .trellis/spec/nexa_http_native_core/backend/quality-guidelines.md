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
- Proxy refresh 策略通过 `RefreshMode` 表达，平台 crate 实现 `ProxyConfigSource`。
- 测试 `ManagedProxyState` 保存的 raw snapshot 时使用 `current_proxy_snapshot()`；`current_platform_state()` 会合并进程级 proxy 环境变量，断言 view 内容时必须提供优先级更高的显式平台值或隔离 proxy 环境变量。

## 禁止模式

- 不要在 core crate 中复制 platform-specific proxy 读取逻辑。
- 不要在 runtime loader 或 executor 中搜索 workspace、pub-cache、release asset 或环境变量路径。
- 不要新增隐藏 fallback：缺 artifact、缺 runtime registration、缺 explicit input 时必须结构化失败。
- 不要为了让测试通过降低 FFI ownership 测试强度，例如只断言 callback 被调用但不验证 free。

## 真实例子

- `native/nexa_http_native_core/tests/runtime_smoke.rs`：覆盖 FFI request、default headers、timeout、body 和 callback。
- `native/nexa_http_native_core/tests/managed_proxy_state.rs`：覆盖 construction-boundary 和 polling refresh 模式。
- `packages/nexa_http/test/ffi_nexa_http_native_data_source_test.dart`：Dart 侧验证 FFI config、request、response 和 cancellation contract。

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

- 产物校验：`fvm dart run scripts/workspace_tools.dart verify-native-abi`
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
- macOS runner: build macOS/iOS artifacts 后运行 `verify-native-abi`。
- Ubuntu runner: build 三个 Android ABIs 后运行 `verify-native-abi`。
- Windows runner: build x64 DLL 后运行 `verify-native-abi`。
- `fvm dart run scripts/workspace_tools.dart verify-development-path`
- `fvm dart run scripts/workspace_tools.dart verify-external-consumer`

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
