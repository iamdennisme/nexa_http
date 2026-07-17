# 目录结构

## 目录布局

```text
packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/
├── Cargo.toml
├── src/
│   ├── lib.rs
│   └── proxy_source.rs
└── tests/proxy_settings.rs
```

## 模块职责

- `src/lib.rs` 只定义 Windows `RUNTIME` 和 runtime wiring，并调用 core `export_nexa_http_ffi!` 生成统一 C ABI exports。
- `src/proxy_source.rs` 实现 `WindowsProxySource`，从 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 读取 proxy 设置。
- `tests/proxy_settings.rs` 验证 `ProxyServer` grammar、core bypass canonicalization 和 quote-preserving behavior。

## 禁止模式

- 不要复制 core runtime、client registry 或 request/response 解析。
- 不要在 Rust FFI crate 中处理 release asset 下载、workspace 查找或 pub-cache 判断。
- 不要从 Rust crate 修改宿主 CMake、Visual Studio project 或 Flutter generated files。

## 状态与持久化边界

- 本 crate 不引入数据库、ORM、migration、文件缓存或其他持久化状态。
- Windows registry 只作为操作系统提供的只读 `Proxy Source`；不得写入 `ProxyEnable`、`ProxyServer`、`ProxyOverride` 或项目自有 key。
- proxy snapshot 由 core `ManagedProxyState` 在进程内持有；runtime、client 和 request lifecycle 由 `nexa_http_native_core` 管理。
- 测试构造 parser input，不修改开发机 registry 或 production 文件。

## 真实例子

- `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/lib.rs`：保留 construction-boundary runtime 并调用共享 ABI export macro。
- `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/proxy_source.rs`：Windows registry proxy 读取。
