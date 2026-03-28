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
    final requestArgs = _NativeRequestArena.fromDto(request);

    try {
      final dispatched = _bindings.nexa_http_client_execute_async(
        clientId,
        requestId,
        requestArgs.pointer,
        _executeCallback.nativeFunction,
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

  int _nextRequestId() {
    _requestSequence += 1;
    return _requestSequence;
  }

  void _handleExecuteCallback(
    int requestId,
    Pointer<NexaHttpResponseHeadResult> resultPointer,
  ) {
    final completer = _pendingExecuteRequests.remove(requestId);
    if (completer == null || completer.isCompleted) {
      _bindings.nexa_http_response_head_result_free(resultPointer);
      return;
    }

    try {
      completer.complete(_decodeResponseHeadResult(resultPointer));
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }

  NexaHttpResponse _decodeResponseHeadResult(
    Pointer<NexaHttpResponseHeadResult> resultPointer,
  ) {
    if (resultPointer == nullptr) {
      throw const NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned a null response head result.',
      );
    }

    var streamId = 0;
    late final int statusCode;
    late final Map<String, List<String>> headers;
    late final Uri? finalUri;

    try {
      final result = resultPointer.ref;
      if (result.is_success == 0) {
        throw _decodeError(result.error_json);
      }

      streamId = result.stream_id;
      if (streamId == 0) {
        throw const NexaHttpException(
          code: 'ffi_invalid_response',
          message:
              'The nexa_http native library returned an invalid response stream handle.',
        );
      }

      statusCode = result.status_code;
      headers = _decodeHeaders(result.headers_ptr, result.headers_len);
      finalUri = _decodeFinalUri(result.final_url_ptr, result.final_url_len);
    } on Object {
      if (streamId != 0) {
        _bindings.nexa_http_response_stream_close(streamId);
      }
      rethrow;
    } finally {
      _bindings.nexa_http_response_head_result_free(resultPointer);
    }

    try {
      return NexaHttpResponse(
        statusCode: statusCode,
        headers: headers,
        bodyBytes: _readResponseBody(streamId),
        finalUri: finalUri,
      );
    } on Object {
      _bindings.nexa_http_response_stream_close(streamId);
      rethrow;
    }
  }

  List<int> _readResponseBody(int streamId) {
    final bodyBytes = BytesBuilder(copy: false);

    while (true) {
      final chunkResultPointer = _bindings.nexa_http_response_stream_next(
        streamId,
      );
      if (chunkResultPointer == nullptr) {
        throw const NexaHttpException(
          code: 'ffi_invalid_response',
          message:
              'The nexa_http native library returned a null response chunk result.',
        );
      }

      try {
        final chunkResult = chunkResultPointer.ref;
        if (chunkResult.is_success == 0) {
          throw _decodeError(chunkResult.error_json);
        }
        if (chunkResult.is_done != 0) {
          return bodyBytes.takeBytes();
        }
        if (chunkResult.chunk_len == 0) {
          continue;
        }
        if (chunkResult.chunk_ptr == nullptr) {
          throw const NexaHttpException(
            code: 'ffi_invalid_response',
            message:
                'The nexa_http native library returned a null chunk pointer for a non-empty response chunk.',
          );
        }

        bodyBytes.add(
          Uint8List.fromList(
            chunkResult.chunk_ptr.asTypedList(chunkResult.chunk_len),
          ),
        );
      } finally {
        _bindings.nexa_http_response_chunk_result_free(chunkResultPointer);
      }
    }
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
      final entry = headersPointer.elementAt(index).ref;
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
    final headerEntries = request.headers.entries.toList(growable: false);
    final headersPointer = headerEntries.isEmpty
        ? nullptr
        : arena<NexaHttpHeaderEntry>(headerEntries.length);

    for (var index = 0; index < headerEntries.length; index += 1) {
      final header = headerEntries[index];
      final name = _NativeUtf8Slice.allocate(header.key, arena);
      final value = _NativeUtf8Slice.allocate(header.value, arena);
      headersPointer[index]
        ..name_ptr = name.pointer.cast()
        ..name_len = name.length
        ..value_ptr = value.pointer.cast()
        ..value_len = value.length;
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
      ..headers_len = headerEntries.length
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
    return _NativeUtf8Slice(
      value.toNativeUtf8(allocator: arena),
      utf8.encode(value).length,
    );
  }
}
