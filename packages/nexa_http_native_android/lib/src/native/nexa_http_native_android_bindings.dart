import 'dart:ffi';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import 'nexa_http_native_ffi.dart' as native;

final class NexaHttpNativeAndroidBindings implements NexaHttpBindings {
  const NexaHttpNativeAndroidBindings();

  @override
  int nexa_http_client_create(Pointer<NexaHttpClientConfigArgs> value) =>
      native.nexa_http_client_create(value);
  @override
  Pointer<Char> nexa_http_take_last_error_json() =>
      native.nexa_http_take_last_error_json();
  @override
  void nexa_http_string_free(Pointer<Char> value) =>
      native.nexa_http_string_free(value);
  @override
  Pointer<Uint8> nexa_http_request_body_alloc(int length) =>
      native.nexa_http_request_body_alloc(length);
  @override
  void nexa_http_request_body_free(Pointer<Uint8> value, int length) =>
      native.nexa_http_request_body_free(value, length);
  @override
  int nexa_http_client_execute_async(
    int clientId,
    int requestId,
    Pointer<NexaHttpRequestArgs> request,
    NexaHttpExecuteCallback callback,
  ) => native.nexa_http_client_execute_async(
    clientId,
    requestId,
    request,
    callback,
  );
  @override
  int nexa_http_client_cancel_request(int clientId, int requestId) =>
      native.nexa_http_client_cancel_request(clientId, requestId);
  @override
  void nexa_http_client_close(int clientId) =>
      native.nexa_http_client_close(clientId);
  @override
  void nexa_http_binary_result_free(Pointer<NexaHttpBinaryResult> result) =>
      native.nexa_http_binary_result_free(result);
  @override
  Pointer<NativeFunction<Void Function(Pointer<NexaHttpBinaryResult>)>>
  get nexaHttpBinaryResultFreeAddress =>
      native.addresses.nexa_http_binary_result_free;
  @override
  Pointer<NativeFunction<Void Function(Pointer<Char>)>>
  get nexaHttpStringFreeAddress => native.addresses.nexa_http_string_free;
}
