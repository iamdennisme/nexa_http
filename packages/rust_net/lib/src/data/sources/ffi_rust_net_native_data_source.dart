import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rust_net/rust_net_bindings_generated.dart';
import 'package:rust_net_core/rust_net_core.dart';

import '../../rinf/rust_net_rinf_runtime.dart';
import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';
import '../dto/native_http_result_dto.dart';
import '../mappers/native_http_error_mapper.dart';
import '../mappers/native_http_response_mapper.dart';
import 'rust_net_native_data_source.dart';

final class FfiRustNetNativeDataSource implements RustNetNativeDataSource {
  FfiRustNetNativeDataSource({required this.libraryPath})
      : _bindings = RustNetBindings(DynamicLibrary.open(libraryPath)),
        _runtime = RustNetRinfRuntime.shared(libraryPath: libraryPath) {
    _responseSubscription ??= _runtime
        .signalsFor(_executeResponseEndpoint)
        .listen(_handleExecuteResponseSignal);
  }

  static const _executeCommandSymbol =
      'rinf_send_dart_signal_rust_net_execute_request';
  static const _executeResponseEndpoint = 'RustNetExecuteResponse';

  static int _requestSequence = 0;
  static StreamSubscription<RustNetRinfSignal>? _responseSubscription;
  static final _pendingExecuteRequests =
      <String, Completer<Map<String, dynamic>>>{};

  final String libraryPath;
  final RustNetBindings _bindings;
  final RustNetRinfRuntime _runtime;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    final configPointer = jsonEncode(config.toJson()).toNativeUtf8();
    try {
      final clientId = _bindings.rust_net_client_create(configPointer.cast());
      if (clientId == 0) {
        throw StateError(
          'Rust native library failed to create an HTTP client.',
        );
      }
      return clientId;
    } finally {
      calloc.free(configPointer);
    }
  }

  @override
  Future<RustNetResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    final requestId = _nextRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingExecuteRequests[requestId] = completer;

    final command = <String, Object?>{
      'request_id': requestId,
      'client_id': clientId,
      'request': request.toJson(),
    };

    _runtime.sendSignal(
      endpointSymbol: _executeCommandSymbol,
      messageBytes: utf8.encode(jsonEncode(command)),
    );

    final payload = await completer.future;
    final resultJson = payload['result'];
    if (resultJson is! Map) {
      throw const RustNetException(
        code: 'ffi_invalid_response',
        message: 'Rust native library returned an invalid execute response.',
      );
    }

    final result = NativeHttpResultDto.fromJson(
      Map<String, dynamic>.from(resultJson.cast<String, Object?>()),
    );
    return result.when(
      success: (response) => NativeHttpResponseMapper.toDomain(response),
      error: (error) => throw NativeHttpErrorMapper.toDomain(error),
    );
  }

  @override
  void closeClient(int clientId) {
    _bindings.rust_net_client_close(clientId);
  }

  static String _nextRequestId() {
    _requestSequence += 1;
    return _requestSequence.toString();
  }

  static void _handleExecuteResponseSignal(RustNetRinfSignal signal) {
    final payload = jsonDecode(signal.messageUtf8);
    if (payload is! Map<dynamic, dynamic>) {
      return;
    }

    final requestId = payload['request_id'];
    if (requestId is! String) {
      return;
    }

    final completer = _pendingExecuteRequests.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    completer.complete(Map<String, dynamic>.from(payload));
  }
}
