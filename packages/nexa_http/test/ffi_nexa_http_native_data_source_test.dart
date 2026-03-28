// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';
import 'package:nexa_http/src/api/api.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/ffi_nexa_http_native_data_source.dart';
import 'package:test/test.dart';

void main() {
  test('encodes structured native request fields without request json', () async {
    late final _FakeNexaHttpBindings bindings;
    bindings = _FakeNexaHttpBindings(
      onExecuteAsync:
          ({
            required int clientId,
            required int requestId,
            required _StructuredRequestWire? structuredRequest,
          }) {
            expect(clientId, 7);
            expect(
              structuredRequest,
              isNotNull,
              reason:
                  'method/url/headers/timeout should be passed through request args',
            );
            expect(structuredRequest!.method, 'POST');
            expect(structuredRequest.url, 'https://example.com/upload');
            expect(structuredRequest.headers, const <String, String>{});
            expect(structuredRequest.timeoutMs, isNull);
            expect(
              structuredRequest.bodyBytes,
              Uint8List.fromList(const <int>[1, 2, 3, 4]),
            );

            return bindings.newSuccessHead(
              statusCode: 200,
              finalUrl: 'https://example.com/upload',
              streamId: 11,
            );
          },
      onStreamNext: ({required int streamId, required int pullCount}) {
        expect(streamId, 11);
        expect(pullCount, 1);
        return bindings.newDoneChunk();
      },
    );

    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: bindings,
    );

    final response = await dataSource.execute(
      7,
      const NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/upload',
        bodyBytes: <int>[1, 2, 3, 4],
      ),
    );

    expect(response.statusCode, 200);
    expect(response.bodyBytes, isEmpty);
    expect(response.finalUri, Uri.parse('https://example.com/upload'));
    expect(bindings.freedHeadCount, 1);
    expect(bindings.freedChunkCount, 1);
  });

  test('decodes streamed native response metadata and body chunks', () async {
    late final _FakeNexaHttpBindings bindings;
    bindings = _FakeNexaHttpBindings(
      onExecuteAsync:
          ({
            required int clientId,
            required int requestId,
            required _StructuredRequestWire? structuredRequest,
          }) {
            expect(clientId, 9);
            expect(requestId, 1);
            expect(structuredRequest, isNotNull);

            return bindings.newSuccessHead(
              statusCode: 201,
              headers: const <MapEntry<String, String>>[
                MapEntry<String, String>('cache-control', 'max-age=60'),
                MapEntry<String, String>('content-type', 'image/png'),
              ],
              finalUrl: 'https://cdn.example.com/final.png',
              streamId: 41,
            );
          },
      onStreamNext: ({required int streamId, required int pullCount}) {
        expect(streamId, 41);
        expect(
          bindings.freedHeadCount,
          1,
          reason: 'response head should be freed before body chunk pulls begin',
        );

        return switch (pullCount) {
          1 => bindings.newSuccessChunk(const <int>[5, 6]),
          2 => bindings.newSuccessChunk(const <int>[7, 8]),
          3 => bindings.newDoneChunk(),
          _ => throw StateError('unexpected pull count $pullCount'),
        };
      },
    );

    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: bindings,
    );

    final response = await dataSource.execute(
      9,
      const NativeHttpRequestDto(
        method: 'GET',
        url: 'https://cdn.example.com/start.png',
      ),
    );

    expect(response.statusCode, 201);
    expect(response.headers, <String, List<String>>{
      'cache-control': <String>['max-age=60'],
      'content-type': <String>['image/png'],
    });
    expect(response.bodyBytes, const <int>[5, 6, 7, 8]);
    expect(response.finalUri, Uri.parse('https://cdn.example.com/final.png'));
    expect(bindings.freedHeadCount, 1);
    expect(bindings.freedChunkCount, 3);
  });

  test('copies streamed chunks before freeing native chunk results', () async {
    late final _FakeNexaHttpBindings bindings;
    bindings = _FakeNexaHttpBindings(
      onExecuteAsync:
          ({
            required int clientId,
            required int requestId,
            required _StructuredRequestWire? structuredRequest,
          }) {
            expect(clientId, 11);
            expect(requestId, 1);
            expect(structuredRequest, isNotNull);

            return bindings.newSuccessHead(statusCode: 202, streamId: 52);
          },
      onStreamNext: ({required int streamId, required int pullCount}) {
        expect(streamId, 52);
        return switch (pullCount) {
          1 => bindings.newSuccessChunk(const <int>[1, 2, 3, 4]),
          2 => bindings.newDoneChunk(),
          _ => throw StateError('unexpected pull count $pullCount'),
        };
      },
      onBeforeFreeChunk: (chunkPointer) {
        final chunk = chunkPointer.ref;
        if (chunk.chunk_ptr != ffi.nullptr && chunk.chunk_len > 0) {
          chunk.chunk_ptr
              .asTypedList(chunk.chunk_len)
              .fillRange(0, chunk.chunk_len, 9);
        }
      },
    );

    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: bindings,
    );

    final response = await dataSource.execute(
      11,
      const NativeHttpRequestDto(
        method: 'GET',
        url: 'https://example.com/streamed-copy',
      ),
    );

    expect(response.bodyBytes, const <int>[1, 2, 3, 4]);
    expect(bindings.freedHeadCount, 1);
    expect(bindings.freedChunkCount, 2);
  });
}

class _FakeNexaHttpBindings extends NexaHttpBindings {
  _FakeNexaHttpBindings({
    required this.onExecuteAsync,
    required this.onStreamNext,
    this.onBeforeFreeChunk,
  }) : super.fromLookup(_unimplementedLookup);

  final ffi.Pointer<NexaHttpResponseHeadResult> Function({
    required int clientId,
    required int requestId,
    required _StructuredRequestWire? structuredRequest,
  })
  onExecuteAsync;
  final ffi.Pointer<NexaHttpResponseChunkResult> Function({
    required int streamId,
    required int pullCount,
  })
  onStreamNext;
  final void Function(ffi.Pointer<NexaHttpResponseChunkResult> value)?
  onBeforeFreeChunk;

  int freedHeadCount = 0;
  int freedChunkCount = 0;
  int _streamPullCount = 0;

  @override
  int nexa_http_client_execute_async(
    int client_id,
    int request_id,
    ffi.Pointer<NexaHttpRequestArgs> request_args,
    NexaHttpExecuteCallback callback,
  ) {
    final resultPointer = onExecuteAsync(
      clientId: client_id,
      requestId: request_id,
      structuredRequest: _StructuredRequestWire.fromPointer(request_args),
    );
    callback
        .asFunction<
          void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
        >()(request_id, resultPointer);
    return 1;
  }

  @override
  ffi.Pointer<NexaHttpResponseChunkResult> nexa_http_response_stream_next(
    int stream_id,
  ) {
    _streamPullCount += 1;
    return onStreamNext(streamId: stream_id, pullCount: _streamPullCount);
  }

  @override
  void nexa_http_response_stream_close(int stream_id) {}

  @override
  void nexa_http_response_head_result_free(
    ffi.Pointer<NexaHttpResponseHeadResult> value,
  ) {
    freedHeadCount += 1;

    final result = value.ref;
    if (result.headers_ptr != ffi.nullptr && result.headers_len > 0) {
      for (var index = 0; index < result.headers_len; index += 1) {
        final entry = result.headers_ptr.elementAt(index).ref;
        if (entry.name_ptr != ffi.nullptr) {
          calloc.free(entry.name_ptr.cast<Utf8>());
        }
        if (entry.value_ptr != ffi.nullptr) {
          calloc.free(entry.value_ptr.cast<Utf8>());
        }
      }
      calloc.free(result.headers_ptr);
    }
    if (result.final_url_ptr != ffi.nullptr) {
      calloc.free(result.final_url_ptr.cast<Utf8>());
    }
    if (result.error_json != ffi.nullptr) {
      calloc.free(result.error_json.cast<Utf8>());
    }
    calloc.free(value);
  }

  @override
  void nexa_http_response_chunk_result_free(
    ffi.Pointer<NexaHttpResponseChunkResult> value,
  ) {
    onBeforeFreeChunk?.call(value);
    freedChunkCount += 1;

    final result = value.ref;
    if (result.chunk_ptr != ffi.nullptr) {
      calloc.free(result.chunk_ptr);
    }
    if (result.error_json != ffi.nullptr) {
      calloc.free(result.error_json.cast<Utf8>());
    }
    calloc.free(value);
  }

  ffi.Pointer<NexaHttpResponseHeadResult> newSuccessHead({
    required int statusCode,
    List<MapEntry<String, String>> headers = const <MapEntry<String, String>>[],
    String? finalUrl,
    required int streamId,
  }) {
    final pointer = calloc<NexaHttpResponseHeadResult>();
    pointer.ref
      ..is_success = 1
      ..status_code = statusCode
      ..headers_ptr = _allocateHeaders(headers)
      ..headers_len = headers.length
      ..final_url_ptr = finalUrl == null
          ? ffi.nullptr
          : finalUrl.toNativeUtf8().cast()
      ..final_url_len = finalUrl == null ? 0 : finalUrl.length
      ..stream_id = streamId
      ..error_json = ffi.nullptr;
    return pointer;
  }

  ffi.Pointer<NexaHttpResponseChunkResult> newSuccessChunk(List<int> bytes) {
    final pointer = calloc<NexaHttpResponseChunkResult>();
    final chunkPointer = calloc<ffi.Uint8>(bytes.length);
    chunkPointer.asTypedList(bytes.length).setAll(0, bytes);
    pointer.ref
      ..is_success = 1
      ..is_done = 0
      ..chunk_ptr = chunkPointer
      ..chunk_len = bytes.length
      ..error_json = ffi.nullptr;
    return pointer;
  }

  ffi.Pointer<NexaHttpResponseChunkResult> newDoneChunk() {
    final pointer = calloc<NexaHttpResponseChunkResult>();
    pointer.ref
      ..is_success = 1
      ..is_done = 1
      ..chunk_ptr = ffi.nullptr
      ..chunk_len = 0
      ..error_json = ffi.nullptr;
    return pointer;
  }
}

ffi.Pointer<T> _unimplementedLookup<T extends ffi.NativeType>(String _) {
  throw UnimplementedError();
}

class _StructuredRequestWire {
  const _StructuredRequestWire({
    required this.method,
    required this.url,
    required this.headers,
    required this.timeoutMs,
    required this.bodyBytes,
  });

  factory _StructuredRequestWire.fromPointer(
    ffi.Pointer<NexaHttpRequestArgs> pointer,
  ) {
    final request = pointer.ref;
    final headers = <String, String>{};
    for (var index = 0; index < request.headers_len; index += 1) {
      final entry = request.headers_ptr.elementAt(index).ref;
      headers[_readUtf8(entry.name_ptr, entry.name_len)] = _readUtf8(
        entry.value_ptr,
        entry.value_len,
      );
    }

    return _StructuredRequestWire(
      method: _readUtf8(request.method_ptr, request.method_len),
      url: _readUtf8(request.url_ptr, request.url_len),
      headers: headers,
      timeoutMs: request.has_timeout == 0 ? null : request.timeout_ms,
      bodyBytes: request.body_ptr == ffi.nullptr
          ? Uint8List(0)
          : Uint8List.fromList(request.body_ptr.asTypedList(request.body_len)),
    );
  }

  final String method;
  final String url;
  final Map<String, String> headers;
  final int? timeoutMs;
  final Uint8List bodyBytes;
}

ffi.Pointer<NexaHttpHeaderEntry> _allocateHeaders(
  List<MapEntry<String, String>> headers,
) {
  if (headers.isEmpty) {
    return ffi.nullptr;
  }

  final pointer = calloc<NexaHttpHeaderEntry>(headers.length);
  for (var index = 0; index < headers.length; index += 1) {
    final header = headers[index];
    pointer[index]
      ..name_ptr = header.key.toNativeUtf8().cast()
      ..name_len = header.key.length
      ..value_ptr = header.value.toNativeUtf8().cast()
      ..value_len = header.value.length;
  }
  return pointer;
}

String _readUtf8(ffi.Pointer<ffi.Char> pointer, int length) {
  if (length == 0) {
    return '';
  }
  return pointer.cast<Utf8>().toDartString(length: length);
}
