import 'dart:ffi';

import 'nexa_http_native_types.dart';

abstract interface class NexaHttpBindings {
  int nexa_http_client_create(Pointer<NexaHttpClientConfigArgs> configArgs);

  Pointer<Char> nexa_http_take_last_error_json();

  void nexa_http_string_free(Pointer<Char> value);

  Pointer<Uint8> nexa_http_request_body_alloc(int bodyLength);

  void nexa_http_request_body_free(Pointer<Uint8> body, int bodyLength);

  int nexa_http_client_execute_async(
    int clientId,
    int requestId,
    Pointer<NexaHttpRequestArgs> requestArgs,
    NexaHttpExecuteCallback callback,
  );

  int nexa_http_client_cancel_request(int clientId, int requestId);

  void nexa_http_client_close(int clientId);

  void nexa_http_binary_result_free(Pointer<NexaHttpBinaryResult> result);

  Pointer<NativeFunction<Void Function(Pointer<NexaHttpBinaryResult>)>>
  get nexaHttpBinaryResultFreeAddress;

  Pointer<NativeFunction<Void Function(Pointer<Char>)>>
  get nexaHttpStringFreeAddress;
}

final class NexaHttpNativeBindingsFactory {
  const NexaHttpNativeBindingsFactory({
    required this.assetId,
    required this.create,
  });

  final String assetId;
  final NexaHttpBindings Function() create;
}

final class NexaHttpNativeBindingsRegistry {
  NexaHttpNativeBindingsRegistry._();

  static NexaHttpNativeBindingsFactory? _factory;
  static NexaHttpBindings? _bindings;

  static void register(NexaHttpNativeBindingsFactory factory) {
    final current = _factory;
    if (current == null) {
      _factory = factory;
      return;
    }
    if (current.assetId == factory.assetId) {
      return;
    }
    throw StateError(
      'Conflicting nexa_http Native Asset registrations: '
      'existing=${current.assetId}; incoming=${factory.assetId}.',
    );
  }

  static NexaHttpBindings resolve() {
    final factory = _factory;
    if (factory == null) {
      throw StateError(
        'No nexa_http Native Asset bindings are registered. '
        'stage=plugin registration; expected_action=depend on the target '
        'platform carrier and use the standard Flutter build/run flow.',
      );
    }
    return _bindings ??= factory.create();
  }

  static bool get isRegistered => _factory != null;

  static String? get assetId => _factory?.assetId;

  static void resetForTesting() {
    _factory = null;
    _bindings = null;
  }
}
