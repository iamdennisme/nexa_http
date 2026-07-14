# 数据库规范

Android FFI crate 没有数据库、ORM、migration 或持久化缓存。

## 规则

- 不要在平台 FFI crate 中引入持久化状态。
- Proxy 设置只从 Android 系统属性当前值读取，并转换成 `ProxySettings`。
- Runtime/client/request 状态由 `nexa_http_native_core` 管理。
- `ManagedProxyState` 只维护进程内的 proxy 快照和刷新线程，不写入本地文件。

## 真实例子

- `src/proxy_source.rs` 在 `load_current_proxy_settings()` 中读取 `getprop` 输出，不写入本地文件。
- `src/lib.rs` 通过 `Lazy<NexaHttpRuntime<ManagedProxyState<AndroidProxySource>>>` 持有进程内 runtime。
