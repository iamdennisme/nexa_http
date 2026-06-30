# 数据库规范

Windows FFI crate 没有数据库、ORM、migration 或持久化缓存。

## 规则

- Registry 读取只用于系统 proxy 设置，不是项目持久化层。
- 不要写入 Windows registry。
- Runtime/client/request 状态由 `nexa_http_native_core` 管理。

## 真实例子

- `src/proxy_source.rs` 只读取 `ProxyEnable`、`ProxyServer`、`ProxyOverride`。
- `src/lib.rs` 通过 `Lazy<NexaHttpRuntime<ManagedProxyState<WindowsProxySource>>>` 持有进程内 runtime。
