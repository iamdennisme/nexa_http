# 数据库规范

macOS FFI crate 没有数据库、ORM、migration 或持久化缓存。

## 规则

- 不要在平台 FFI crate 中引入持久化状态。
- Proxy 设置只从系统 API 当前值读取，并转换成 `ProxySettings`。
- Runtime/client/request 状态由 `nexa_http_native_core` 管理。

## 真实例子

- `src/proxy_source.rs` 从 macOS SystemConfiguration 读取当前 proxy 字段，不写入本地文件。
- `src/lib.rs` 通过 `Lazy<NexaHttpRuntime<ManagedProxyState<MacosProxySource>>>` 持有进程内 runtime。
