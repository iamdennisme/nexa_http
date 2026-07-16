# ADR-0006: Response Body 单次消费与确定性所有权

## 状态

Accepted

## 背景

Native Transport 当前可以把 native response bytes 以 zero-copy view 交给 Dart，但如果公开 API 允许长期、重复读取该 view，正常资源释放就依赖调用者记住 `close()` 或等待 finalizer。另一方面，简单地在 transport、mapper 和 public body 各复制一次会损失大 body 的性能优势。

## 决策

`ResponseBody` 是一次性消费对象。Native callback decoder 到 public body 之间保持同一个 adopted native view，不做中间 body copy。

- `string()` 直接从 native view 解码，在成功或失败后释放 native ownership，不先复制完整 byte buffer。
- 非空 native-adopted body 的 `bytes()` 恰好执行一次 native-to-Dart copy，返回 Dart-owned `Uint8List` 后立即释放 native ownership。Dart-buffered body 直接转移已拥有的 buffer；空 body 不执行无意义的零字节 copy。
- `close()` 不读取、不复制，并幂等释放。
- 第二次消费抛 `StateError`。
- 删除当前把完整 buffer 包成单个 event 的 `byteStream()`；只有 Native Transport 支持真实 incremental delivery、cancellation 和 backpressure 后才重新设计 streaming API。
- Native finalizer 只处理调用者遗忘或异常中断，不是正常生命周期。

## 后果

- Response mapper、Response constructor 和 content-type 处理不得复制 body。
- Ownership tests 必须证明 success、decode error、explicit close、late cleanup 和 finalizer path 都只释放一次。
- Performance tests 必须区分必要的最终消费转换与重复中间复制；`bytes()` 允许一次 copy，`string()` 不允许预复制完整 byte buffer。
- Public API 不承诺可重复读取 Response Body；需要重复使用内容的调用者持有 `bytes()` 返回的 Dart-owned value 或 `string()` 返回值。

## 拒绝的替代方案

- 公开长期 native-backed bytes 并要求调用者手动 close：拒绝，因为正常 ownership 依赖使用者纪律。
- 在 decoder、mapper 和 public body 多层 defensive copy：拒绝，因为复制次数随分层增加。
- 保留当前假的 `byteStream()`：拒绝，因为完整缓冲后发送一个 event 不是真实 streaming contract。

## 当前来源

- `packages/nexa_http/lib/src/api/response_body.dart`
- `packages/nexa_http/lib/src/data/sources/ffi_nexa_http_response_decoder.dart`
- `packages/nexa_http/test/response_body_test.dart`
- `.trellis/spec/nexa_http/dart/public-api.md`
- `.trellis/spec/nexa_http/dart/native-transport.md`
