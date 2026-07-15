# HTTP API Context

本上下文定义宿主 App 描述 HTTP 操作时使用的公开语言。Native Transport、平台能力和 artifact 集成不属于本上下文。

## Language

**Host App**:
集成并调用 `nexa_http` 的 Flutter 应用。
_Avoid_: Consumer runtime, native host

**Public Dart SDK**:
Host App 使用的 HTTP 语义集合，是本项目唯一受支持的 runtime API。
_Avoid_: Native SDK, carrier API, FFI API

**HTTP Client**:
持有一组 Client Configuration、用于创建 Call 的长期对象。
_Avoid_: Native client, transport lease

**Client Configuration**:
应用于 HTTP Client 的默认请求设置，例如 base URL、headers、timeout 和 user agent。
_Avoid_: Native config, runtime config

**Request**:
一次 HTTP 操作的不可变描述，包含 method、URL、headers 和可选 Request Body。
_Avoid_: Native request, FFI request

**Request Body**:
Request 携带的内容及其 media type；由外部 bytes 构造时，Request Body 接管该内容的独占所有权。
_Avoid_: Payload buffer, native body

**Call**:
由 HTTP Client 和一个 Request 创建、最多执行一次的 HTTP 操作实例。
_Avoid_: Request execution, transport request

**Cancellation**:
幂等地停止一个尚未完成的 Call 的意图；取消先取得终态时，Call 以 `canceled` HTTP Failure 完成。它不表示远端一定没有收到请求。
_Avoid_: Dispose, client close

**Response**:
Call 完成后得到的 HTTP 结果，包含 status、headers、最终 URL 和可选 Response Body。
_Avoid_: Transport response, native result

**Response Body**:
Response 携带的一次性可消费内容；读取完成或显式关闭时自动释放其资源。
_Avoid_: Native bytes, binary result

**HTTP Failure**:
Call 未能产生正常 Response 时暴露给 Host App 的结构化失败；应用只根据稳定的 Failure Kind 决定控制流。
_Avoid_: Native error JSON, bootstrap error

**Failure Kind**:
HTTP Failure 的有限公开类别：canceled、timeout、network、invalid request、configuration、unavailable 或 internal。
_Avoid_: Native code, FFI stage, string error code
