import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../../api/api.dart';
import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_error_dto.dart';
import '../dto/native_http_request_dto.dart';
import '../mappers/native_http_error_mapper.dart';
import 'nexa_http_native_data_source.dart';

final class FfiNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  FfiNexaHttpNativeDataSource({
    required DynamicLibrary library,
    NexaHttpBindings? bindings,
  }) : _bindings = bindings ?? NexaHttpBindings(library) {
    _executeCallback = NativeCallable<NexaHttpExecuteCallbackFunction>.listener(
      _handleExecuteCallback,
    );
  }

  final NexaHttpBindings _bindings;
  final _pendingExecuteRequests = <int, Completer<NexaHttpResponse>>{};

  late final NativeCallable<NexaHttpExecuteCallbackFunction> _executeCallback;
  int _requestSequence = 0;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    final configPointer = jsonEncode(config.toJson()).toNativeUtf8();
    try {
      final clientId = _bindings.nexa_http_client_create(configPointer.cast());
      if (clientId == 0) {
        throw StateError(
          'The nexa_http native library failed to create an HTTP client.',
        );
      }
      return clientId;
    } finally {
      calloc.free(configPointer);
    }
  }

  @override
  Future<NexaHttpResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    final requestId = _nextRequestId();
    final completer = Completer<NexaHttpResponse>();
    _pendingExecuteRequests[requestId] = completer;

    final requestPointer = jsonEncode(request.toJson()).toNativeUtf8();
    final bodyPointer = _copyRequestBody(request.bodyBytes);
    final bodyLength = request.bodyBytes?.length ?? 0;

    try {
      final dispatched = _bindings.nexa_http_client_execute_async(
        clientId,
        requestId,
        requestPointer.cast(),
        bodyPointer,
        bodyLength,
        _executeCallback.nativeFunction,
      );

      if (dispatched == 0) {
        throw const NexaHttpException(
          code: 'ffi_dispatch_failed',
          message: 'The nexa_http native library failed to dispatch the request.',
        );
      }
    } catch (error, stackTrace) {
      _pendingExecuteRequests.remove(requestId);
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      calloc.free(requestPointer);
      if (bodyPointer != nullptr) {
        calloc.free(bodyPointer);
      }
    }

    return completer.future;
  }

  @override
  void closeClient(int clientId) {
    _bindings.nexa_http_client_close(clientId);
  }

  int _nextRequestId() {
    _requestSequence += 1;
    return _requestSequence;
  }

  void _handleExecuteCallback(
    int requestId,
    Pointer<NexaHttpBinaryResult> resultPointer,
  ) {
    final completer = _pendingExecuteRequests.remove(requestId);
    if (completer == null || completer.isCompleted) {
      _bindings.nexa_http_binary_result_free(resultPointer);
      return;
    }

    try {
      final response = _decodeBinaryResult(resultPointer);
      completer.complete(response);
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _bindings.nexa_http_binary_result_free(resultPointer);
    }
  }

  NexaHttpResponse _decodeBinaryResult(
    Pointer<NexaHttpBinaryResult> resultPointer,
  ) {
    if (resultPointer == nullptr) {
      throw const NexaHttpException(
        code: 'ffi_invalid_response',
        message: 'The nexa_http native library returned a null binary result.',
      );
    }

    final result = resultPointer.ref;
    if (result.is_success == 0) {
      throw _decodeError(result.error_json);
    }

    return NexaHttpResponse(
      statusCode: result.status_code,
      headers: _decodeHeaders(result.headers_json),
      bodyBytes: _decodeBody(result),
      finalUri: _decodeFinalUri(result.final_url),
    );
  }

  Pointer<Uint8> _copyRequestBody(List<int>? bodyBytes) {
    if (bodyBytes == null || bodyBytes.isEmpty) {
      return nullptr;
    }

    final pointer = calloc<Uint8>(bodyBytes.length);
    pointer.asTypedList(bodyBytes.length).setAll(0, bodyBytes);
    return pointer;
  }

  Map<String, List<String>> _decodeHeaders(Pointer<Char> headersPointer) {
    if (headersPointer == nullptr) {
      return const <String, List<String>>{};
    }

    final decoded = jsonDecode(headersPointer.cast<Utf8>().toDartString());
    if (decoded is! Map) {
      throw const NexaHttpException(
        code: 'ffi_invalid_response',
        message: 'The nexa_http native library returned invalid response headers.',
      );
    }

    return decoded.map<String, List<String>>((key, value) {
      final values = value is List
          ? value.map((item) => '$item').toList(growable: false)
          : <String>['$value'];
      return MapEntry('$key', values);
    });
  }

  List<int> _decodeBody(NexaHttpBinaryResult result) {
    if (result.body_ptr == nullptr || result.body_len == 0) {
      return const <int>[];
    }

    return Uint8List.fromList(result.body_ptr.asTypedList(result.body_len));
  }

  Uri? _decodeFinalUri(Pointer<Char> finalUrlPointer) {
    if (finalUrlPointer == nullptr) {
      return null;
    }
    return Uri.tryParse(finalUrlPointer.cast<Utf8>().toDartString());
  }

  NexaHttpException _decodeError(Pointer<Char> errorPointer) {
    if (errorPointer == nullptr) {
      return const NexaHttpException(
        code: 'ffi_invalid_response',
        message: 'The nexa_http native library returned an invalid error result.',
      );
    }

    final decoded = jsonDecode(errorPointer.cast<Utf8>().toDartString());
    if (decoded is! Map) {
      return const NexaHttpException(
        code: 'ffi_invalid_response',
        message: 'The nexa_http native library returned invalid error payload.',
      );
    }

    return NativeHttpErrorMapper.toDomain(
      NativeHttpErrorDto.fromJson(
        Map<String, dynamic>.from(decoded.cast<String, Object?>()),
      ),
    );
  }
}
