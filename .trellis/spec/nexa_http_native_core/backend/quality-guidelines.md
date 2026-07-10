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
