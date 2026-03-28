// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:io';
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

            final resultPointer = calloc<NexaHttpBinaryResult>();
            resultPointer.ref
              ..is_success = 1
              ..status_code = 200
              ..headers_ptr = ffi.nullptr
              ..headers_len = 0
              ..final_url_ptr = 'https://example.com/upload'
                  .toNativeUtf8()
                  .cast()
              ..final_url_len = 'https://example.com/upload'.length
              ..error_json = ffi.nullptr;

            final bodyPointer = calloc<ffi.Uint8>(3);
            bodyPointer.asTypedList(3).setAll(0, const <int>[9, 8, 7]);
            resultPointer.ref
              ..body_ptr = bodyPointer
              ..body_len = 3;

            bindings.trackResult(resultPointer);
            callback
                .asFunction<
                  void Function(int, ffi.Pointer<NexaHttpBinaryResult>)
                >()(requestId, resultPointer);
            return 1;
          },
    );

    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: bindings,
      binaryResultFinalizer: ffi.nullptr,
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
    expect(response.bodyBytes, const <int>[9, 8, 7]);
    expect(response.finalUri, Uri.parse('https://example.com/upload'));
    expect(bindings.freedResultCount, 0);

    bindings.freeTrackedResult();
    expect(bindings.freedResultCount, 1);
  });

  test(
    'decodes structured native response metadata without header json',
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
              expect(clientId, 9);
              expect(structuredRequest, isNotNull);

              final resultPointer = calloc<NexaHttpBinaryResult>();
              final headersPointer =
                  _allocateHeaders(const <MapEntry<String, String>>[
                    MapEntry<String, String>('cache-control', 'max-age=60'),
                    MapEntry<String, String>('content-type', 'image/png'),
                  ]);
              resultPointer.ref
                ..is_success = 1
                ..status_code = 201
                ..headers_ptr = headersPointer
                ..headers_len = 2
                ..final_url_ptr = 'https://cdn.example.com/final.png'
                    .toNativeUtf8()
                    .cast()
                ..final_url_len = 'https://cdn.example.com/final.png'.length
                ..error_json = ffi.nullptr;

              final bodyPointer = calloc<ffi.Uint8>(4);
              bodyPointer.asTypedList(4).setAll(0, const <int>[5, 6, 7, 8]);
              resultPointer.ref
                ..body_ptr = bodyPointer
                ..body_len = 4;

              bindings.trackResult(resultPointer);
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpBinaryResult>)
                  >()(requestId, resultPointer);
              return 1;
            },
      );

      final dataSource = FfiNexaHttpNativeDataSource(
        library: ffi.DynamicLibrary.process(),
        bindings: bindings,
        binaryResultFinalizer: ffi.nullptr,
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
      expect(bindings.freedResultCount, 0);

      bindings.freeTrackedResult();
      expect(bindings.freedResultCount, 1);
    },
  );

  test(
    'frees native response buffers exactly once after body adoption',
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
              expect(clientId, 11);
              expect(structuredRequest, isNotNull);

              final resultPointer = calloc<NexaHttpBinaryResult>();
              final bodyPointer = calloc<ffi.Uint8>(4);
              bodyPointer.asTypedList(4).setAll(0, const <int>[1, 2, 3, 4]);
              resultPointer.ref
                ..is_success = 1
                ..status_code = 202
                ..headers_ptr = ffi.nullptr
                ..headers_len = 0
                ..final_url_ptr = ffi.nullptr
                ..final_url_len = 0
                ..body_ptr = bodyPointer
                ..body_len = 4
                ..error_json = ffi.nullptr;

              bindings.trackResult(resultPointer);
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpBinaryResult>)
                  >()(requestId, resultPointer);
              return 1;
            },
      );
      final dataSource = FfiNexaHttpNativeDataSource(
        library: ffi.DynamicLibrary.process(),
        bindings: bindings,
        binaryResultFinalizer: ffi.nullptr,
      );

      final response = await dataSource.execute(
        11,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/image.png',
        ),
      );

      expect(response.bodyBytes, const <int>[1, 2, 3, 4]);
      expect(bindings.freedResultCount, 0);

      bindings.overwriteTrackedBody(const <int>[7, 6, 5, 4]);
      expect(
        response.bodyBytes,
        const <int>[7, 6, 5, 4],
        reason:
            'body bytes should adopt the native buffer instead of copying it',
      );

      bindings.freeTrackedResult();
      expect(bindings.freedResultCount, 1);
    },
  );

  test(
    'releases adopted native response buffers through the production finalizer',
    () async {
      final support = await _NativeBinaryResultTestSupport.load();
      final bindings = _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              expect(clientId, 12);
              final resultPointer = support.createSuccessResult(const <int>[
                3,
                1,
                4,
                1,
              ]);
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpBinaryResult>)
                  >()(requestId, resultPointer);
              return 1;
            },
        onFreeBinaryResult: support.freeResult,
      );
      final dataSource = FfiNexaHttpNativeDataSource(
        library: support.library,
        bindings: bindings,
        binaryResultFinalizer: support.finalizer,
      );

      final (
        bodyReference,
        resultPointer,
      ) = await _executeAndReleaseAdoptedResponse(
        dataSource,
        support,
        clientId: 12,
        request: const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/finalizer-success',
        ),
        expectedBody: const <int>[3, 1, 4, 1],
      );

      expect(support.freeCount(resultPointer), 0);
      await _waitForNativeFinalizer(
        support,
        resultPointer,
        bodyReference: bodyReference,
        expectedCount: 1,
      );
      await _assertNativeFreeCountRemains(
        support,
        resultPointer,
        expectedCount: 1,
      );
    },
    skip: !Platform.isMacOS
        ? 'real native finalizer coverage requires the host macOS dylib'
        : false,
  );

  test(
    'does not double free adopted native buffers when later metadata decoding fails',
    () async {
      final support = await _NativeBinaryResultTestSupport.load();
      final bindings = _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              expect(clientId, 13);
              final resultPointer = support.createSuccessResult(const <int>[
                8,
                6,
                7,
                5,
              ], invalidFinalUrl: true);
              callback
                  .asFunction<
                    void Function(int, ffi.Pointer<NexaHttpBinaryResult>)
                  >()(requestId, resultPointer);
              return 1;
            },
        onFreeBinaryResult: support.freeResult,
      );
      final dataSource = FfiNexaHttpNativeDataSource(
        library: support.library,
        bindings: bindings,
        binaryResultFinalizer: support.finalizer,
      );

      await expectLater(
        () => dataSource.execute(
          13,
          const NativeHttpRequestDto(
            method: 'GET',
            url: 'https://example.com/finalizer-error',
          ),
        ),
        throwsA(
          isA<NexaHttpException>().having(
            (error) => error.code,
            'code',
            'ffi_invalid_response',
          ),
        ),
      );

      final resultPointer = support.lastCreatedResultPointer;
      await _waitForNativeFreeCount(support, resultPointer, expectedCount: 1);
      expect(
        support.freeCount(resultPointer),
        1,
        reason:
            'decode errors after body adoption must not leave a second finalizer-triggered free behind',
      );
    },
    skip: !Platform.isMacOS
        ? 'real native finalizer coverage requires the host macOS dylib'
        : false,
  );

  test('preferSynchronousExecution uses the binary execution path', () async {
    var executeAsyncCalls = 0;
    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              executeAsyncCalls += 1;
              return 0;
            },
      ),
      binaryResultFinalizer: ffi.nullptr,
      preferSynchronousExecution: true,
      binaryExecutor: (clientId, request) async {
        expect(clientId, 21);
        expect(request.method, 'GET');
        expect(request.url, 'https://example.com/sync');
        return const NexaHttpResponse(
          statusCode: 204,
          bodyBytes: <int>[],
        );
      },
    );

    final response = await dataSource.execute(
      21,
      const NativeHttpRequestDto(
        method: 'GET',
        url: 'https://example.com/sync',
      ),
    );

    expect(response.statusCode, 204);
    expect(executeAsyncCalls, 0);
  });
}

class _FakeNexaHttpBindings extends NexaHttpBindings {
  _FakeNexaHttpBindings({required this.onExecuteAsync, this.onFreeBinaryResult})
    : super.fromLookup(_unimplementedLookup);

  final int Function({
    required int clientId,
    required int requestId,
    required _StructuredRequestWire? structuredRequest,
    required NexaHttpExecuteCallback callback,
  })
  onExecuteAsync;
  final void Function(ffi.Pointer<NexaHttpBinaryResult> value)?
  onFreeBinaryResult;

  int freedResultCount = 0;
  ffi.Pointer<NexaHttpBinaryResult> _trackedResultPointer = ffi.nullptr;
  final Set<int> _freedResultAddresses = <int>{};

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

  void trackResult(ffi.Pointer<NexaHttpBinaryResult> resultPointer) {
    _trackedResultPointer = resultPointer;
  }

  void overwriteTrackedBody(List<int> bytes) {
    if (_trackedResultPointer == ffi.nullptr) {
      throw StateError('No tracked native result is available.');
    }
    final result = _trackedResultPointer.ref;
    result.body_ptr.asTypedList(result.body_len).setAll(0, bytes);
  }

  void freeTrackedResult() {
    if (_trackedResultPointer == ffi.nullptr) {
      throw StateError('No tracked native result is available.');
    }
    nexa_http_binary_result_free(_trackedResultPointer);
  }

  @override
  void nexa_http_binary_result_free(ffi.Pointer<NexaHttpBinaryResult> value) {
    if (onFreeBinaryResult case final onFreeBinaryResult?) {
      onFreeBinaryResult(value);
      if (_trackedResultPointer.address == value.address) {
        _trackedResultPointer = ffi.nullptr;
      }
      return;
    }

    if (!_freedResultAddresses.add(value.address)) {
      throw StateError(
        'native result ${value.address} was freed more than once',
      );
    }
    freedResultCount += 1;
    if (value.ref.headers_ptr != ffi.nullptr && value.ref.headers_len > 0) {
      for (var index = 0; index < value.ref.headers_len; index += 1) {
      final entry = (value.ref.headers_ptr + index).ref;
        if (entry.name_ptr != ffi.nullptr) {
          calloc.free(entry.name_ptr.cast<Utf8>());
        }
        if (entry.value_ptr != ffi.nullptr) {
          calloc.free(entry.value_ptr.cast<Utf8>());
        }
      }
      calloc.free(value.ref.headers_ptr);
    }
    if (value.ref.final_url_ptr != ffi.nullptr) {
      calloc.free(value.ref.final_url_ptr.cast<Utf8>());
    }
    if (value.ref.body_ptr != ffi.nullptr) {
      calloc.free(value.ref.body_ptr);
    }
    calloc.free(value);
    if (_trackedResultPointer.address == value.address) {
      _trackedResultPointer = ffi.nullptr;
    }
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
      final entry = (request.headers_ptr + index).ref;
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
  final pointer = calloc<NexaHttpHeaderEntry>(headers.length);
  for (var index = 0; index < headers.length; index += 1) {
    final header = headers[index];
    (pointer + index).ref
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

typedef _NativeCreateBinaryResultDart =
    ffi.Pointer<NexaHttpBinaryResult> Function(
      ffi.Pointer<ffi.Uint8>,
      int,
      int,
    );
typedef _NativeCreateBinaryResultC =
    ffi.Pointer<NexaHttpBinaryResult> Function(
      ffi.Pointer<ffi.Uint8>,
      ffi.UintPtr,
      ffi.Uint8,
    );
typedef _NativeBinaryResultFreeCountDart =
    int Function(ffi.Pointer<NexaHttpBinaryResult>);
typedef _NativeBinaryResultFreeCountC =
    ffi.UintPtr Function(ffi.Pointer<NexaHttpBinaryResult>);
typedef _NativeBinaryResultFreeDart =
    void Function(ffi.Pointer<NexaHttpBinaryResult>);
typedef _NativeBinaryResultFreeC =
    ffi.Void Function(ffi.Pointer<NexaHttpBinaryResult>);
typedef _NativeTestBinaryResultFinalizerNative =
    ffi.Void Function(ffi.Pointer<ffi.Void>);

final class _NativeBinaryResultTestSupport {
  _NativeBinaryResultTestSupport._({
    required this.library,
    required _NativeCreateBinaryResultDart createBinaryResult,
    required _NativeBinaryResultFreeCountDart freeCount,
    required _NativeBinaryResultFreeDart freeResult,
    required this.finalizer,
  }) : _createBinaryResult = createBinaryResult,
       _freeCount = freeCount,
       _freeResult = freeResult;

  final ffi.DynamicLibrary library;
  final _NativeCreateBinaryResultDart _createBinaryResult;
  final _NativeBinaryResultFreeCountDart _freeCount;
  final _NativeBinaryResultFreeDart _freeResult;
  final ffi.Pointer<ffi.NativeFunction<_NativeTestBinaryResultFinalizerNative>>
  finalizer;
  ffi.Pointer<NexaHttpBinaryResult> lastCreatedResultPointer = ffi.nullptr;

  static Future<_NativeBinaryResultTestSupport> load() async {
    final libraryPath = await _resolveHostNativeLibraryPath();
    final library = ffi.DynamicLibrary.open(libraryPath);
    return _NativeBinaryResultTestSupport._(
      library: library,
      createBinaryResult: library
          .lookupFunction<
            _NativeCreateBinaryResultC,
            _NativeCreateBinaryResultDart
          >('nexa_http_test_binary_result_new_success'),
      freeCount: library
          .lookupFunction<
            _NativeBinaryResultFreeCountC,
            _NativeBinaryResultFreeCountDart
          >('nexa_http_test_binary_result_free_count'),
      freeResult: library
          .lookupFunction<
            _NativeBinaryResultFreeC,
            _NativeBinaryResultFreeDart
          >('nexa_http_test_binary_result_free'),
      finalizer: library
          .lookup<ffi.NativeFunction<_NativeTestBinaryResultFinalizerNative>>(
            'nexa_http_test_binary_result_free',
          ),
    );
  }

  ffi.Pointer<NexaHttpBinaryResult> createSuccessResult(
    List<int> bodyBytes, {
    bool invalidFinalUrl = false,
  }) {
    final bodyPointer = calloc<ffi.Uint8>(bodyBytes.length);
    bodyPointer.asTypedList(bodyBytes.length).setAll(0, bodyBytes);
    try {
      lastCreatedResultPointer = _createBinaryResult(
        bodyPointer,
        bodyBytes.length,
        invalidFinalUrl ? 1 : 0,
      );
      return lastCreatedResultPointer;
    } finally {
      calloc.free(bodyPointer);
    }
  }

  int freeCount(ffi.Pointer<NexaHttpBinaryResult> resultPointer) {
    return _freeCount(resultPointer);
  }

  void freeResult(ffi.Pointer<NexaHttpBinaryResult> resultPointer) {
    _freeResult(resultPointer);
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
    'Unable to locate the host nexa_http macOS test library for FFI ownership tests.',
  );
}

Future<(WeakReference<Object>, ffi.Pointer<NexaHttpBinaryResult>)>
_executeAndReleaseAdoptedResponse(
  FfiNexaHttpNativeDataSource dataSource,
  _NativeBinaryResultTestSupport support, {
  required int clientId,
  required NativeHttpRequestDto request,
  required List<int> expectedBody,
}) async {
  final response = await dataSource.execute(clientId, request);
  final bodyReference = WeakReference<Object>(response.bodyBytes as Object);
  expect(response.bodyBytes, expectedBody);
  return (bodyReference, support.lastCreatedResultPointer);
}

Future<void> _waitForNativeFinalizer(
  _NativeBinaryResultTestSupport support,
  ffi.Pointer<NexaHttpBinaryResult> resultPointer, {
  required int expectedCount,
  required WeakReference<Object> bodyReference,
}) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await _collectAllGarbage();
    if (bodyReference.target == null &&
        support.freeCount(resultPointer) == expectedCount) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  fail(
    'expected collected body and native free count $expectedCount for ${resultPointer.address}, '
    'got bodyReference=${bodyReference.target} freeCount=${support.freeCount(resultPointer)}',
  );
}

Future<void> _waitForNativeFreeCount(
  _NativeBinaryResultTestSupport support,
  ffi.Pointer<NexaHttpBinaryResult> resultPointer, {
  required int expectedCount,
}) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await _collectAllGarbage();
    if (support.freeCount(resultPointer) == expectedCount) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  fail(
    'expected native free count $expectedCount for ${resultPointer.address}, '
    'got ${support.freeCount(resultPointer)}',
  );
}

Future<void> _assertNativeFreeCountRemains(
  _NativeBinaryResultTestSupport support,
  ffi.Pointer<NexaHttpBinaryResult> resultPointer, {
  required int expectedCount,
}) async {
  for (var attempt = 0; attempt < 3; attempt += 1) {
    await _collectAllGarbage();
    expect(support.freeCount(resultPointer), expectedCount);
  }
}

Future<void> _collectAllGarbage() async {
  final serviceInfo = await developer.Service.controlWebServer(
    enable: true,
    silenceOutput: true,
  );
  final serverUri = serviceInfo.serverWebSocketUri;
  final isolateId = developer.Service.getIsolateId(Isolate.current);
  if (serverUri == null || isolateId == null) {
    throw StateError('The Dart VM service is unavailable for forcing GC.');
  }

  final socket = await WebSocket.connect(serverUri.toString());
  try {
    final response = Completer<void>();
    late final StreamSubscription<dynamic> subscription;
    subscription = socket.listen((message) {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      if (decoded['id'] == 'gc') {
        subscription.cancel();
        if (decoded.containsKey('error')) {
          response.completeError(
            StateError('VM service GC failed: ${decoded['error']}'),
          );
        } else {
          response.complete();
        }
      }
    });
    socket.add(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 'gc',
        'method': '_collectAllGarbage',
        'params': <String, Object?>{'isolateId': isolateId},
      }),
    );
    await response.future.timeout(const Duration(seconds: 2));
  } finally {
    await socket.close();
  }
}
