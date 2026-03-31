import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../../api/nexa_http_exception.dart';
import '../../internal/transport/native_response_body_bytes.dart';
import '../../internal/transport/transport_response.dart';
import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_error_dto.dart';
import '../dto/native_http_request_dto.dart';
import '../mappers/native_http_error_mapper.dart';
import 'nexa_http_native_data_source.dart';

typedef BinaryResultFinalizerNative = Void Function(Pointer<Void> token);

final class FfiNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  factory FfiNexaHttpNativeDataSource({
    required DynamicLibrary library,
    NexaHttpBindings? bindings,
    Pointer<NativeFunction<BinaryResultFinalizerNative>>? binaryResultFinalizer,
  }) {
    final resolvedBindings = bindings ?? NexaHttpBindings(library);

    return FfiNexaHttpNativeDataSource._(
      bindings: resolvedBindings,
      binaryResultFinalizer:
          binaryResultFinalizer ??
          library.lookup<NativeFunction<BinaryResultFinalizerNative>>(
            'nexa_http_binary_result_free',
          ),
    );
  }

  FfiNexaHttpNativeDataSource._({
    required NexaHttpBindings bindings,
    required Pointer<NativeFunction<BinaryResultFinalizerNative>>
    binaryResultFinalizer,
  }) : _bindings = bindings,
       _binaryResultNativeFinalizer = binaryResultFinalizer == nullptr
           ? null
           : NativeFinalizer(binaryResultFinalizer.cast()) {
    _executeCallback = NativeCallable<NexaHttpExecuteCallbackFunction>.listener(
      _handleExecuteCallback,
    );
  }

  final NexaHttpBindings _bindings;
  final NativeFinalizer? _binaryResultNativeFinalizer;
  final _pendingExecuteRequests = <int, Completer<TransportResponse>>{};

  NativeCallable<NexaHttpExecuteCallbackFunction>? _executeCallback;
  int _requestSequence = 0;
  bool _disposeRequested = false;
  bool _isDisposed = false;

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
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    final requestId = _nextRequestId();
    final completer = Completer<TransportResponse>();
    _pendingExecuteRequests[requestId] = completer;
    final requestArgs = _NativeRequestArena.fromDto(request);

    try {
      final dispatched = _bindings.nexa_http_client_execute_async(
        clientId,
        requestId,
        requestArgs.pointer,
        _executeCallback!.nativeFunction,
      );

      if (dispatched == 0) {
        throw const NexaHttpException(
          code: 'ffi_dispatch_failed',
          message:
              'The nexa_http native library failed to dispatch the request.',
        );
      }
    } catch (error, stackTrace) {
      _pendingExecuteRequests.remove(requestId);
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      requestArgs.dispose();
    }

    return completer.future;
  }

  @override
  void closeClient(int clientId) {
    _bindings.nexa_http_client_close(clientId);
  }

  @override
  void dispose() {
    if (_disposeRequested || _isDisposed) {
      return;
    }
    _disposeRequested = true;
    _maybeDisposeCallback();
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
      _maybeDisposeCallback();
      return;
    }

    var releaseResultPointer = true;
    try {
      final response = _decodeBinaryResult(resultPointer);
      releaseResultPointer = !_adoptsBodyOwnership(resultPointer.ref);
      completer.complete(response);
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      if (releaseResultPointer) {
        _bindings.nexa_http_binary_result_free(resultPointer);
      }
      _maybeDisposeCallback();
    }
  }

  TransportResponse _decodeBinaryResult(
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

    final headers = _decodeHeaders(result.headers_ptr, result.headers_len);
    final finalUri = _decodeFinalUri(
      result.final_url_ptr,
      result.final_url_len,
    );
    final bodyBytes = _takeResponseBody(resultPointer, result);

    return TransportResponse(
      statusCode: result.status_code,
      headers: headers,
      bodyBytes: bodyBytes,
      finalUri: finalUri,
    );
  }

  Map<String, List<String>> _decodeHeaders(
    Pointer<NexaHttpHeaderEntry> headersPointer,
    int headersLength,
  ) {
    if (headersLength == 0) {
      return const <String, List<String>>{};
    }
    if (headersPointer == nullptr) {
      throw const NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned invalid response headers.',
      );
    }

    final headers = <String, List<String>>{};
    for (var index = 0; index < headersLength; index += 1) {
      final entry = (headersPointer + index).ref;
      final name = _decodeSizedString(
        entry.name_ptr,
        entry.name_len,
        fieldName: 'response header name',
      );
      final value = _decodeSizedString(
        entry.value_ptr,
        entry.value_len,
        fieldName: 'response header value',
      );
      (headers[name] ??= <String>[]).add(value);
    }
    return headers;
  }

  List<int> _takeResponseBody(
    Pointer<NexaHttpBinaryResult> resultPointer,
    NexaHttpBinaryResult result,
  ) {
    if (result.body_len == 0) {
      return const <int>[];
    }
    if (result.body_ptr == nullptr) {
      throw const NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned a null body pointer for a non-empty response body.',
      );
    }

    final bytes = result.body_ptr.asTypedList(result.body_len);
    return adoptNativeResponseBodyBytes(
      bytes,
      release: () => _bindings.nexa_http_binary_result_free(resultPointer),
      finalizer: _binaryResultNativeFinalizer,
      finalizerToken: resultPointer.cast(),
      externalSize: result.body_len,
    );
  }

  bool _adoptsBodyOwnership(NexaHttpBinaryResult result) {
    return result.body_ptr != nullptr && result.body_len > 0;
  }

  void _maybeDisposeCallback() {
    if (!_disposeRequested ||
        _pendingExecuteRequests.isNotEmpty ||
        _isDisposed) {
      return;
    }

    final callback = _executeCallback;
    _executeCallback = null;
    _isDisposed = true;
    callback?.close();
  }

  Uri? _decodeFinalUri(Pointer<Char> finalUrlPointer, int finalUrlLength) {
    if (finalUrlLength == 0) {
      return null;
    }
    return Uri.tryParse(
      _decodeSizedString(
        finalUrlPointer,
        finalUrlLength,
        fieldName: 'final response URL',
      ),
    );
  }

  NexaHttpException _decodeError(Pointer<Char> errorPointer) {
    if (errorPointer == nullptr) {
      return const NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned an invalid error result.',
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

  String _decodeSizedString(
    Pointer<Char> pointer,
    int length, {
    required String fieldName,
  }) {
    if (length == 0) {
      return '';
    }
    if (pointer == nullptr) {
      throw NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned a null pointer for $fieldName.',
      );
    }
    return pointer.cast<Utf8>().toDartString(length: length);
  }
}

final class _NativeRequestArena {
  _NativeRequestArena._(this._arena, this.pointer);

  final Arena _arena;
  final Pointer<NexaHttpRequestArgs> pointer;

  factory _NativeRequestArena.fromDto(NativeHttpRequestDto request) {
    final arena = Arena();
    final pointer = arena<NexaHttpRequestArgs>();
    final method = _NativeUtf8Slice.allocate(request.method, arena);
    final url = _NativeUtf8Slice.allocate(request.url, arena);
    final headers = request.headers;
    final headersLength = headers.length;
    final headersPointer = headersLength == 0
        ? nullptr
        : arena<NexaHttpHeaderEntry>(headersLength);

    var index = 0;
    for (final header in headers) {
      final name = _NativeUtf8Slice.allocate(header.key, arena);
      final value = _NativeUtf8Slice.allocate(header.value, arena);
      headersPointer[index]
        ..name_ptr = name.pointer.cast()
        ..name_len = name.length
        ..value_ptr = value.pointer.cast()
        ..value_len = value.length;
      index += 1;
    }

    final bodyBytes = request.bodyBytes;
    final bodyPointer = bodyBytes == null || bodyBytes.isEmpty
        ? nullptr
        : arena<Uint8>(bodyBytes.length);
    if (bodyPointer != nullptr) {
      bodyPointer.asTypedList(bodyBytes!.length).setAll(0, bodyBytes);
    }

    final timeoutMs = request.timeoutMs;
    pointer.ref
      ..method_ptr = method.pointer.cast()
      ..method_len = method.length
      ..url_ptr = url.pointer.cast()
      ..url_len = url.length
      ..headers_ptr = headersPointer
      ..headers_len = headersLength
      ..body_ptr = bodyPointer
      ..body_len = bodyBytes?.length ?? 0
      ..timeout_ms = timeoutMs ?? 0
      ..has_timeout = timeoutMs == null ? 0 : 1;

    return _NativeRequestArena._(arena, pointer);
  }

  void dispose() {
    _arena.releaseAll();
  }
}

final class _NativeUtf8Slice {
  const _NativeUtf8Slice(this.pointer, this.length);

  final Pointer<Utf8> pointer;
  final int length;

  factory _NativeUtf8Slice.allocate(String value, Arena arena) {
    final encoded = utf8.encode(value);
    final pointer = arena<Uint8>(encoded.length + 1);
    final bytes = pointer.asTypedList(encoded.length + 1);
    bytes.setAll(0, encoded);
    bytes[encoded.length] = 0;
    return _NativeUtf8Slice(pointer.cast(), encoded.length);
  }
}
