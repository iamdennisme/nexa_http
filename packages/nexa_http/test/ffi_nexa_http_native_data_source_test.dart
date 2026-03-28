// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:mirrors';
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
            required NexaHttpExecuteCallback callback,
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

            final resultPointer = bindings.newSuccessHead(
              statusCode: 200,
              finalUrl: 'https://example.com/upload',
              streamId: 11,
            );
            callback
                .asFunction<
                  void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                >()(requestId, resultPointer);
            return 1;
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
    expect(await response.readBytes(), isEmpty);
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
            required NexaHttpExecuteCallback callback,
          }) {
            expect(clientId, 9);
            expect(requestId, 1);
            expect(structuredRequest, isNotNull);

            final resultPointer = bindings.newSuccessHead(
              statusCode: 201,
              headers: const <MapEntry<String, String>>[
                MapEntry<String, String>('cache-control', 'max-age=60'),
                MapEntry<String, String>('content-type', 'image/png'),
              ],
              finalUrl: 'https://cdn.example.com/final.png',
              streamId: 41,
            );
            callback
                .asFunction<
                  void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                >()(requestId, resultPointer);
            return 1;
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
    expect(await response.readBytes(), const <int>[5, 6, 7, 8]);
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
            required NexaHttpExecuteCallback callback,
          }) {
            expect(clientId, 11);
            expect(requestId, 1);
            expect(structuredRequest, isNotNull);

            final resultPointer = bindings.newSuccessHead(
              statusCode: 202,
              streamId: 52,
            );
            callback
                .asFunction<
                  void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                >()(requestId, resultPointer);
            return 1;
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

    expect(await response.readBytes(), const <int>[1, 2, 3, 4]);
    expect(bindings.freedHeadCount, 1);
    expect(bindings.freedChunkCount, 2);
  });

  test(
    'closes native response streams when body stream subscriptions are cancelled',
    () async {
      late final _FakeNexaHttpBindings bindings;
      bindings = _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              expect(clientId, 14);
              expect(requestId, 1);
              expect(structuredRequest, isNotNull);

              final resultPointer = bindings.newSuccessHead(
                statusCode: 200,
                streamId: 81,
              );
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                  >()(requestId, resultPointer);
              return 1;
            },
        onStreamNext: ({required int streamId, required int pullCount}) {
          expect(streamId, 81);
          return switch (pullCount) {
            1 => bindings.newSuccessChunk(const <int>[9, 8, 7]),
            _ => throw StateError(
              'stream should have been cancelled after the first chunk',
            ),
          };
        },
      );

      final dataSource = FfiNexaHttpNativeDataSource(
        library: ffi.DynamicLibrary.process(),
        bindings: bindings,
      );

      final response = await dataSource.execute(
        14,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/cancel-stream',
        ),
      );

      late final StreamSubscription<Uint8List> subscription;
      final cancelCompleter = Completer<void>();
      subscription = response.bodyStream.listen((chunk) {
        expect(chunk, Uint8List.fromList(const <int>[9, 8, 7]));
        subscription.cancel().then(cancelCompleter.complete);
      });

      await cancelCompleter.future;

      expect(bindings.closedStreamIds, <int>[81]);
      expect(bindings.freedHeadCount, 1);
      expect(bindings.freedChunkCount, 1);
    },
  );

  test(
    'closes native response streams when an unconsumed response is explicitly closed',
    () async {
      late final _FakeNexaHttpBindings bindings;
      bindings = _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              expect(clientId, 15);
              expect(requestId, 1);
              expect(structuredRequest, isNotNull);

              final resultPointer = bindings.newSuccessHead(
                statusCode: 200,
                streamId: 82,
              );
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                  >()(requestId, resultPointer);
              return 1;
            },
        onStreamNext: ({required int streamId, required int pullCount}) {
          throw StateError('unconsumed response should not pull body chunks');
        },
      );

      final dataSource = FfiNexaHttpNativeDataSource(
        library: ffi.DynamicLibrary.process(),
        bindings: bindings,
      );

      final response = await dataSource.execute(
        15,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/unconsumed-close',
        ),
      );

      response.close();

      expect(bindings.closedStreamIds, <int>[82]);
      expect(bindings.freedHeadCount, 1);
      expect(bindings.freedChunkCount, 0);
    },
  );

  test(
    'closes orphaned native streams when an async callback arrives after completion',
    () async {
      late final _FakeNexaHttpBindings bindings;
      bindings = _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              expect(clientId, 12);

              final deliver = callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                  >();
              deliver(
                requestId,
                bindings.newSuccessHead(statusCode: 200, streamId: 61),
              );
              return 1;
            },
        onStreamNext: ({required int streamId, required int pullCount}) {
          expect(streamId, 61);
          expect(pullCount, 1);
          return bindings.newDoneChunk();
        },
      );

      final dataSource = FfiNexaHttpNativeDataSource(
        library: ffi.DynamicLibrary.process(),
        bindings: bindings,
      );

      final response = await dataSource.execute(
        12,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/orphaned-callback',
        ),
      );

      expect(response.statusCode, 200);
      expect(await response.readBytes(), isEmpty);
      final dataSourceMirror = reflect(dataSource);
      final dataSourceLibrary = dataSourceMirror.type.owner as LibraryMirror;
      dataSourceMirror.invoke(
        MirrorSystem.getSymbol('_handleExecuteCallback', dataSourceLibrary),
        <Object>[
          bindings.lastRequestId!,
          bindings.newSuccessHead(statusCode: 204, streamId: 62),
        ],
      );
      expect(bindings.closedStreamIds, <int>[62]);
      expect(bindings.freedHeadCount, 2);
      expect(bindings.freedChunkCount, 1);
    },
  );

  test(
    'uses the real native head and chunk free functions from Dart',
    () async {
      final support = await _NativeStreamResultTestSupport.load();
      ffi.Pointer<NexaHttpResponseHeadResult>? createdHead;
      ffi.Pointer<NexaHttpResponseChunkResult>? createdChunk;
      ffi.Pointer<NexaHttpResponseChunkResult>? doneChunk;

      final bindings = _HybridNexaHttpBindings(
        support.library,
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              expect(clientId, 13);
              createdHead = support.createSuccessHead(streamId: 71);
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpResponseHeadResult>)
                  >()(requestId, createdHead!);
              return 1;
            },
        onStreamNext: ({required int streamId, required int pullCount}) {
          expect(streamId, 71);
          return switch (pullCount) {
            1 => createdChunk = support.createSuccessChunk(const <int>[4, 2]),
            2 => doneChunk = support.createDoneChunk(),
            _ => throw StateError('unexpected pull count $pullCount'),
          }!;
        },
      );

      final dataSource = FfiNexaHttpNativeDataSource(
        library: support.library,
        bindings: bindings,
      );

      final response = await dataSource.execute(
        13,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/real-native-free',
        ),
      );

      expect(response.statusCode, 200);
      expect(await response.readBytes(), const <int>[4, 2]);
      expect(support.headFreeCount(createdHead!), 1);
      expect(support.chunkFreeCount(createdChunk!), 1);
      expect(support.chunkFreeCount(doneChunk!), 1);
    },
    skip: !Platform.isMacOS
        ? 'real native free-path coverage requires the host macOS dylib'
        : false,
  );
}

class _FakeNexaHttpBindings extends NexaHttpBindings {
  _FakeNexaHttpBindings({
    required this.onExecuteAsync,
    required this.onStreamNext,
    this.onBeforeFreeChunk,
  }) : super.fromLookup(_unimplementedLookup);

  final int Function({
    required int clientId,
    required int requestId,
    required _StructuredRequestWire? structuredRequest,
    required NexaHttpExecuteCallback callback,
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
  int? lastRequestId;
  final List<int> closedStreamIds = <int>[];

  @override
  int nexa_http_client_execute_async(
    int client_id,
    int request_id,
    ffi.Pointer<NexaHttpRequestArgs> request_args,
    NexaHttpExecuteCallback callback,
  ) {
    lastRequestId = request_id;
    return onExecuteAsync(
      clientId: client_id,
      requestId: request_id,
      structuredRequest: _StructuredRequestWire.fromPointer(request_args),
      callback: callback,
    );
  }

  @override
  ffi.Pointer<NexaHttpResponseChunkResult> nexa_http_response_stream_next(
    int stream_id,
  ) {
    _streamPullCount += 1;
    return onStreamNext(streamId: stream_id, pullCount: _streamPullCount);
  }

  @override
  void nexa_http_response_stream_close(int stream_id) {
    closedStreamIds.add(stream_id);
  }

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

final class _HybridNexaHttpBindings extends NexaHttpBindings {
  _HybridNexaHttpBindings(
    ffi.DynamicLibrary library, {
    required this.onExecuteAsync,
    required this.onStreamNext,
  }) : super(library);

  final int Function({
    required int clientId,
    required int requestId,
    required _StructuredRequestWire? structuredRequest,
    required NexaHttpExecuteCallback callback,
  })
  onExecuteAsync;
  final ffi.Pointer<NexaHttpResponseChunkResult> Function({
    required int streamId,
    required int pullCount,
  })
  onStreamNext;

  int _streamPullCount = 0;

  @override
  int nexa_http_client_execute_async(
    int client_id,
    int request_id,
    ffi.Pointer<NexaHttpRequestArgs> request_args,
    NexaHttpExecuteCallback callback,
  ) {
    return onExecuteAsync(
      clientId: client_id,
      requestId: request_id,
      structuredRequest: _StructuredRequestWire.fromPointer(request_args),
      callback: callback,
    );
  }

  @override
  ffi.Pointer<NexaHttpResponseChunkResult> nexa_http_response_stream_next(
    int stream_id,
  ) {
    _streamPullCount += 1;
    return onStreamNext(streamId: stream_id, pullCount: _streamPullCount);
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

typedef _NativeCreateResponseHeadResultDart =
    ffi.Pointer<NexaHttpResponseHeadResult> Function(int streamId);
typedef _NativeCreateResponseHeadResultC =
    ffi.Pointer<NexaHttpResponseHeadResult> Function(ffi.Uint64 streamId);
typedef _NativeResponseHeadFreeCountDart =
    int Function(ffi.Pointer<NexaHttpResponseHeadResult>);
typedef _NativeResponseHeadFreeCountC =
    ffi.UintPtr Function(ffi.Pointer<NexaHttpResponseHeadResult>);
typedef _NativeCreateResponseChunkResultDart =
    ffi.Pointer<NexaHttpResponseChunkResult> Function(
      ffi.Pointer<ffi.Uint8>,
      int,
    );
typedef _NativeCreateResponseChunkResultC =
    ffi.Pointer<NexaHttpResponseChunkResult> Function(
      ffi.Pointer<ffi.Uint8>,
      ffi.UintPtr,
    );
typedef _NativeCreateResponseDoneChunkResultDart =
    ffi.Pointer<NexaHttpResponseChunkResult> Function();
typedef _NativeCreateResponseDoneChunkResultC =
    ffi.Pointer<NexaHttpResponseChunkResult> Function();
typedef _NativeResponseChunkFreeCountDart =
    int Function(ffi.Pointer<NexaHttpResponseChunkResult>);
typedef _NativeResponseChunkFreeCountC =
    ffi.UintPtr Function(ffi.Pointer<NexaHttpResponseChunkResult>);

final class _NativeStreamResultTestSupport {
  _NativeStreamResultTestSupport._({
    required this.library,
    required _NativeCreateResponseHeadResultDart createSuccessHead,
    required _NativeResponseHeadFreeCountDart headFreeCount,
    required _NativeCreateResponseChunkResultDart createSuccessChunk,
    required _NativeCreateResponseDoneChunkResultDart createDoneChunk,
    required _NativeResponseChunkFreeCountDart chunkFreeCount,
  }) : _createSuccessHead = createSuccessHead,
       _headFreeCount = headFreeCount,
       _createSuccessChunk = createSuccessChunk,
       _createDoneChunk = createDoneChunk,
       _chunkFreeCount = chunkFreeCount;

  final ffi.DynamicLibrary library;
  final _NativeCreateResponseHeadResultDart _createSuccessHead;
  final _NativeResponseHeadFreeCountDart _headFreeCount;
  final _NativeCreateResponseChunkResultDart _createSuccessChunk;
  final _NativeCreateResponseDoneChunkResultDart _createDoneChunk;
  final _NativeResponseChunkFreeCountDart _chunkFreeCount;

  static Future<_NativeStreamResultTestSupport> load() async {
    final buildResult = await Process.run('cargo', <String>[
      'build',
      '--manifest-path',
      '${Directory.current.path}/../nexa_http_native_macos/native/nexa_http_native_macos_ffi/Cargo.toml',
    ]);
    if (buildResult.exitCode != 0) {
      throw StateError(
        'Failed to build the host nexa_http macOS test library: ${buildResult.stderr}',
      );
    }

    final libraryPath = await _resolveHostNativeLibraryPath();
    final library = ffi.DynamicLibrary.open(libraryPath);
    return _NativeStreamResultTestSupport._(
      library: library,
      createSuccessHead: library
          .lookupFunction<
            _NativeCreateResponseHeadResultC,
            _NativeCreateResponseHeadResultDart
          >('nexa_http_test_response_head_result_new_success'),
      headFreeCount: library
          .lookupFunction<
            _NativeResponseHeadFreeCountC,
            _NativeResponseHeadFreeCountDart
          >('nexa_http_test_response_head_result_free_count'),
      createSuccessChunk: library
          .lookupFunction<
            _NativeCreateResponseChunkResultC,
            _NativeCreateResponseChunkResultDart
          >('nexa_http_test_response_chunk_result_new_success'),
      createDoneChunk: library
          .lookupFunction<
            _NativeCreateResponseDoneChunkResultC,
            _NativeCreateResponseDoneChunkResultDart
          >('nexa_http_test_response_chunk_result_new_done'),
      chunkFreeCount: library
          .lookupFunction<
            _NativeResponseChunkFreeCountC,
            _NativeResponseChunkFreeCountDart
          >('nexa_http_test_response_chunk_result_free_count'),
    );
  }

  ffi.Pointer<NexaHttpResponseHeadResult> createSuccessHead({
    required int streamId,
  }) {
    return _createSuccessHead(streamId);
  }

  int headFreeCount(ffi.Pointer<NexaHttpResponseHeadResult> resultPointer) {
    return _headFreeCount(resultPointer);
  }

  ffi.Pointer<NexaHttpResponseChunkResult> createSuccessChunk(List<int> bytes) {
    final bytesPointer = calloc<ffi.Uint8>(bytes.length);
    bytesPointer.asTypedList(bytes.length).setAll(0, bytes);
    try {
      return _createSuccessChunk(bytesPointer, bytes.length);
    } finally {
      calloc.free(bytesPointer);
    }
  }

  ffi.Pointer<NexaHttpResponseChunkResult> createDoneChunk() {
    return _createDoneChunk();
  }

  int chunkFreeCount(ffi.Pointer<NexaHttpResponseChunkResult> resultPointer) {
    return _chunkFreeCount(resultPointer);
  }
}

Future<String> _resolveHostNativeLibraryPath() async {
  final candidates = <String>[
    '${Directory.current.path}/../../target/debug/libnexa_http_native_macos_ffi.dylib',
    '${Directory.current.path}/../../target/release/libnexa_http_native_macos_ffi.dylib',
    '${Directory.current.path}/../nexa_http_native_macos/macos/Libraries/libnexa_http_native.dylib',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError(
    'Unable to locate the host nexa_http macOS test library for FFI stream ownership tests.',
  );
}
