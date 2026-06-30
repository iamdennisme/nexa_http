# 数据库规范

iOS FFI crate 没有数据库、ORM、migration 或持久化缓存。

## 规则

- 不要在平台 FFI crate 中引入持久化状态。
- Proxy 设置只从系统当前值转换成 `ProxySettings`。
- Runtime/client/request 状态由 `nexa_http_native_core` 管理。

## 真实例子

- `src/proxy_source.rs` 读取 Apple proxy 字段并返回内存结构。
- `src/lib.rs` 通过 `Lazy<NexaHttpRuntime<ManagedProxyState<IosProxySource>>>` 持有进程内 runtime。
