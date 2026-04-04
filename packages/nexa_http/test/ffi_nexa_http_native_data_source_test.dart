// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';
import 'package:nexa_http/src/api/api.dart';
import 'package:nexa_http/src/data/mappers/native_http_client_config_mapper.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/ffi_nexa_http_native_data_source.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/config/client_options.dart';
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
            expect(
              structuredRequest.headers,
              const <MapEntry<String, String>>[],
            );
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
      NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/upload',
        bodyBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.bodyBytes, const <int>[9, 8, 7]);
    expect(response.finalUri, Uri.parse('https://example.com/upload'));
    expect(bindings.freedResultCount, 0);
    expect(bindings.freedRequestBodyCount, 0);

    bindings.freeTrackedResult();
    expect(bindings.freedResultCount, 1);
  });

  test(
    'preserves repeated structured request headers on the FFI wire',
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
              expect(clientId, 8);
              expect(structuredRequest, isNotNull);
              expect(
                structuredRequest!.headers
                    .map((header) => (header.key, header.value))
                    .toList(),
                equals(const <(String, String)>[
                  ('accept', 'application/json'),
                  ('accept', 'application/problem+json'),
                ]),
              );

              final resultPointer = calloc<NexaHttpBinaryResult>();
              resultPointer.ref
                ..is_success = 1
                ..status_code = 204
                ..headers_ptr = ffi.nullptr
                ..headers_len = 0
                ..final_url_ptr = ffi.nullptr
                ..final_url_len = 0
                ..body_ptr = ffi.nullptr
                ..body_len = 0
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
        8,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/items',
          headers: <MapEntry<String, String>>[
            MapEntry<String, String>('accept', 'application/json'),
            MapEntry<String, String>('accept', 'application/problem+json'),
          ],
        ),
      );

      expect(response.statusCode, 204);
      expect(bindings.freedResultCount, 1);
    },
  );

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

  test('always dispatches requests through execute_async', () async {
    late final _FakeNexaHttpBindings bindings;
    var executeAsyncCalls = 0;
    bindings = _FakeNexaHttpBindings(
      onExecuteAsync:
          ({
            required int clientId,
            required int requestId,
            required _StructuredRequestWire? structuredRequest,
            required NexaHttpExecuteCallback callback,
          }) {
            executeAsyncCalls += 1;
            final resultPointer = calloc<NexaHttpBinaryResult>();
            resultPointer.ref
              ..is_success = 1
              ..status_code = 204
              ..headers_ptr = ffi.nullptr
              ..headers_len = 0
              ..final_url_ptr = ffi.nullptr
              ..final_url_len = 0
              ..body_ptr = ffi.nullptr
              ..body_len = 0
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
      21,
      NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/async-only',
        bodyBytes: Uint8List.fromList(const <int>[4, 2]),
      ),
    );

    expect(response.statusCode, 204);
    expect(executeAsyncCalls, 1);
    expect(bindings.freedResultCount, 1);
  });

  test('dispatch failures still surface as ffi_dispatch_failed', () async {
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
              expect(clientId, 22);
              expect(
                structuredRequest?.url,
                'https://example.com/dispatch-fail',
              );
              return 0;
            },
      ),
      binaryResultFinalizer: ffi.nullptr,
    );

    await expectLater(
      () => dataSource.execute(
        22,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/dispatch-fail',
        ),
      ),
      throwsA(
        isA<NexaHttpException>().having(
          (error) => error.code,
          'code',
          'ffi_dispatch_failed',
        ),
      ),
    );
  });

  test(
    'cancel completes pending requests and frees late native results',
    () async {
      late final _FakeNexaHttpBindings bindings;
      late NexaHttpExecuteCallback capturedCallback;
      late int capturedRequestId;
      bindings = _FakeNexaHttpBindings(
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              capturedRequestId = requestId;
              capturedCallback = callback;
              return 1;
            },
      );
      final dataSource = FfiNexaHttpNativeDataSource(
        library: ffi.DynamicLibrary.process(),
        bindings: bindings,
        binaryResultFinalizer: ffi.nullptr,
      );

      CancelNativeRequest? cancelRequest;
      final responseFuture = dataSource.execute(
        31,
        const NativeHttpRequestDto(
          method: 'GET',
          url: 'https://example.com/cancel',
        ),
        onCancelReady: (value) => cancelRequest = value,
      );

      expect(cancelRequest, isNotNull);
      cancelRequest!.call();

      await expectLater(
        responseFuture,
        throwsA(
          isA<NexaHttpException>().having(
            (error) => error.code,
            'code',
            'canceled',
          ),
        ),
      );
      expect(bindings.canceledRequestCount, 1);

      final resultPointer = calloc<NexaHttpBinaryResult>();
      resultPointer.ref
        ..is_success = 1
        ..status_code = 204
        ..headers_ptr = ffi.nullptr
        ..headers_len = 0
        ..final_url_ptr = ffi.nullptr
        ..final_url_len = 0
        ..body_ptr = ffi.nullptr
        ..body_len = 0
        ..error_json = ffi.nullptr;

      bindings.trackResult(resultPointer);
      capturedCallback
          .asFunction<void Function(int, ffi.Pointer<NexaHttpBinaryResult>)>()(
        capturedRequestId,
        resultPointer,
      );
      await Future<void>.delayed(Duration.zero);
      expect(bindings.freedResultCount, 1);
    },
  );

  test('createClient only encodes config fields consumed by Rust', () {
    late _StructuredConfigWire capturedConfig;
    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: _FakeNexaHttpBindings(
        onCreateClient: (configArgs) {
          capturedConfig = _StructuredConfigWire.fromPointer(configArgs);
          return 77;
        },
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              throw UnimplementedError(
                'execute_async is not used by this test',
              );
            },
      ),
      binaryResultFinalizer: ffi.nullptr,
    );

    final clientId = dataSource.createClient(
      NativeHttpClientConfigMapper.toDto(
        ClientOptions(
          baseUrl: Uri.parse('https://example.com/api/'),
          defaultHeaders: <String, String>{'x-client': 'nexa'},
          timeout: Duration(seconds: 2),
          userAgent: 'nexa-test',
        ),
      ),
    );

    expect(clientId, 77);
    expect(capturedConfig.defaultHeaders, <String, String>{'x-client': 'nexa'});
    expect(capturedConfig.timeoutMs, 2000);
    expect(capturedConfig.userAgent, 'nexa-test');
  });

  test('createClient surfaces structured native bootstrap errors', () {
    final dataSource = FfiNexaHttpNativeDataSource(
      library: ffi.DynamicLibrary.process(),
      bindings: _FakeNexaHttpBindings(
        onCreateClient: (_) => 0,
        onTakeLastErrorJson: () => jsonEncode(<String, Object?>{
          'code': 'native_bootstrap_failed',
          'message': 'native client bootstrap failed',
          'details': <String, Object?>{
            'stage': 'client_create',
            'native_code': 'invalid_proxy',
          },
        }).toNativeUtf8().cast(),
        onExecuteAsync:
            ({
              required int clientId,
              required int requestId,
              required _StructuredRequestWire? structuredRequest,
              required NexaHttpExecuteCallback callback,
            }) {
              throw UnimplementedError();
            },
      ),
      binaryResultFinalizer: ffi.nullptr,
    );

    expect(
      () => dataSource.createClient(
        NativeHttpClientConfigDto(),
      ),
      throwsA(
        isA<NexaHttpException>()
            .having((error) => error.code, 'code', 'native_bootstrap_failed')
            .having(
              (error) => error.details?['stage'],
              'details.stage',
              'client_create',
            )
            .having(
              (error) => error.details?['native_code'],
              'details.native_code',
              'invalid_proxy',
            ),
      ),
    );
  });
}

class _FakeNexaHttpBindings extends NexaHttpBindings {
  _FakeNexaHttpBindings({
    this.onCreateClient,
    this.onTakeLastErrorJson,
    required this.onExecuteAsync,
  }) : super.fromLookup(_unimplementedLookup);

  final int Function(ffi.Pointer<NexaHttpClientConfigArgs> configArgs)?
  onCreateClient;
  final ffi.Pointer<ffi.Char> Function()? onTakeLastErrorJson;
  final int Function({
    required int clientId,
    required int requestId,
    required _StructuredRequestWire? structuredRequest,
    required NexaHttpExecuteCallback callback,
  })
  onExecuteAsync;

  int freedResultCount = 0;
  int freedRequestBodyCount = 0;
  int canceledRequestCount = 0;
  ffi.Pointer<NexaHttpBinaryResult> _trackedResultPointer = ffi.nullptr;
  final Set<int> _freedResultAddresses = <int>{};

  @override
  int nexa_http_client_create(
    ffi.Pointer<NexaHttpClientConfigArgs> config_args,
  ) {
    final onCreateClient = this.onCreateClient;
    if (onCreateClient == null) {
      return 1;
    }
    return onCreateClient(config_args);
  }

  @override
  ffi.Pointer<ffi.Char> nexa_http_take_last_error_json() {
    final onTakeLastErrorJson = this.onTakeLastErrorJson;
    if (onTakeLastErrorJson == null) {
      return ffi.nullptr;
    }
    return onTakeLastErrorJson();
  }

  @override
  ffi.Pointer<ffi.Uint8> nexa_http_request_body_alloc(int body_len) {
    return calloc<ffi.Uint8>(body_len);
  }

  @override
  void nexa_http_request_body_free(
    ffi.Pointer<ffi.Uint8> body_ptr,
    int body_len,
  ) {
    freedRequestBodyCount += 1;
    calloc.free(body_ptr);
  }

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
  int nexa_http_client_cancel_request(int client_id, int request_id) {
    canceledRequestCount += 1;
    return 1;
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
      if (value.ref.body_owner == ffi.nullptr) {
        calloc.free(value.ref.body_ptr);
      }
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
    required this.bodyOwned,
  });

  factory _StructuredRequestWire.fromPointer(
    ffi.Pointer<NexaHttpRequestArgs> pointer,
  ) {
    final request = pointer.ref;
    final headers = <MapEntry<String, String>>[];
    for (var index = 0; index < request.headers_len; index += 1) {
      final entry = (request.headers_ptr + index).ref;
      headers.add(
        MapEntry<String, String>(
          _readUtf8(entry.name_ptr, entry.name_len),
          _readUtf8(entry.value_ptr, entry.value_len),
        ),
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
      bodyOwned: request.body_owned != 0,
    );
  }

  final String method;
  final String url;
  final List<MapEntry<String, String>> headers;
  final int? timeoutMs;
  final Uint8List bodyBytes;
  final bool bodyOwned;
}

class _StructuredConfigWire {
  const _StructuredConfigWire({
    required this.defaultHeaders,
    required this.timeoutMs,
    required this.userAgent,
  });

  factory _StructuredConfigWire.fromPointer(
    ffi.Pointer<NexaHttpClientConfigArgs> pointer,
  ) {
    final config = pointer.ref;
    final defaultHeaders = <String, String>{};
    for (var index = 0; index < config.default_headers_len; index += 1) {
      final entry = (config.default_headers_ptr + index).ref;
      defaultHeaders[_readUtf8(entry.name_ptr, entry.name_len)] = _readUtf8(
        entry.value_ptr,
        entry.value_len,
      );
    }

    return _StructuredConfigWire(
      defaultHeaders: defaultHeaders,
      timeoutMs: config.has_timeout == 0 ? null : config.timeout_ms,
      userAgent: config.user_agent_ptr == ffi.nullptr
          ? null
          : _readUtf8(config.user_agent_ptr, config.user_agent_len),
    );
  }

  final Map<String, String> defaultHeaders;
  final int? timeoutMs;
  final String? userAgent;
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
