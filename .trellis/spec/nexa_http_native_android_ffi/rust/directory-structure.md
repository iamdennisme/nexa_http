# 目录结构

## 目录布局

```text
packages/nexa_http_native_android/native/nexa_http_native_android_ffi/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   └── proxy_source.rs
└── tests/proxy_settings.rs
```

## 模块职责

- `src/lib.rs` 只定义 Android `RUNTIME` 和 runtime wiring，并调用 core `export_nexa_http_ffi!` 生成统一 C ABI exports。
- `src/proxy_source.rs` 实现 `AndroidProxySource`，通过 Android `getprop` 读取系统 proxy 设置。
- `tests/proxy_settings.rs` 验证 `getprop` 字段解析、core shared bypass 分隔符/canonicalization 和 refresh mode。

## Android proxy 字段

- HTTP proxy 使用 `http.proxyHost` 和 `http.proxyPort`，默认端口是 `80`。
- HTTPS proxy 使用 `https.proxyHost` 和 `https.proxyPort`，默认端口是 `443`。
- SOCKS proxy 使用 `socksProxyHost` 和 `socksProxyPort`，默认端口是 `1080`，写入 `ProxySettings::all`。
- Bypass list 合并 `http.nonProxyHosts` 和 `https.nonProxyHosts`，调用 core `split_bypass_rules` 与 `canonicalize_bypass_rules` 支持 `,`、`;`、`|` 分隔并按小写去重；Android 自己不复制这些规则。

## 禁止模式

- 不要在 Android crate 中复制 request/response/client registry/runtime executor 逻辑。
- 不要在 Rust FFI crate 中处理 release asset 下载、workspace 查找或 pub-cache 判断；这些属于 Dart build hook / internal package。
- 不要改变 `nexa_http_*` C ABI 函数名，除非同步所有平台 crate、Dart bindings 和 tests。

## 状态与持久化边界

- 本 crate 不引入数据库、ORM、migration、文件缓存或其他持久化状态。
- `AndroidProxySource` 只读取 Android 系统属性的当前值；`ManagedProxyState` 只维护进程内 snapshot 和刷新线程。
- runtime、client 和 request lifecycle 由 `nexa_http_native_core` 管理，本 crate 不创建第二份 registry。
- 测试通过 `BTreeMap<String, String>` 注入 proxy 字段，不写入 production 配置文件。

## 真实例子

- `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/lib.rs`：保留 polling runtime 并调用共享 ABI export macro。
- `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/proxy_source.rs`：平台专属 proxy source 和 `getprop` 字段解析。
- `packages/nexa_http_native_android/native/nexa_http_native_android_ffi/tests/proxy_settings.rs`：验证 `current_proxy_settings_for_test()` 和 polling refresh policy。
