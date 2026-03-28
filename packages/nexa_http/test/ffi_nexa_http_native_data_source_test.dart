// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/ffi_nexa_http_native_data_source.dart';
import 'package:test/test.dart';

void main() {
  test('encodes structured native request fields without request json',
      () async {
    final bindings = _FakeNexaHttpBindings(
      onExecuteAsync: ({
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
        expect(structuredRequest.bodyBytes,
            Uint8List.fromList(const <int>[1, 2, 3, 4]));

        final resultPointer = calloc<NexaHttpBinaryResult>();
        resultPointer.ref
          ..is_success = 1
          ..status_code = 200
          ..headers_ptr = ffi.nullptr
          ..headers_len = 0
          ..final_url_ptr = 'https://example.com/upload'.toNativeUtf8().cast()
          ..final_url_len = 'https://example.com/upload'.length
          ..error_json = ffi.nullptr;

        final bodyPointer = calloc<ffi.Uint8>(3);
        bodyPointer.asTypedList(3).setAll(0, const <int>[9, 8, 7]);
        resultPointer.ref
          ..body_ptr = bodyPointer
          ..body_len = 3;

        callback.asFunction<
            void Function(int, ffi.Pointer<NexaHttpBinaryResult>)>()(
          requestId,
          resultPointer,
        );
        return 1;
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
    expect(response.bodyBytes, const <int>[9, 8, 7]);
    expect(response.finalUri, Uri.parse('https://example.com/upload'));
    expect(bindings.freedResultCount, 1);
  });

  test('decodes structured native response metadata without header json',
      () async {
    final bindings = _FakeNexaHttpBindings(
      onExecuteAsync: ({
        required int clientId,
        required int requestId,
        required _StructuredRequestWire? structuredRequest,
        required NexaHttpExecuteCallback callback,
      }) {
        expect(clientId, 9);
        expect(structuredRequest, isNotNull);

        final resultPointer = calloc<NexaHttpBinaryResult>();
        final headersPointer = _allocateHeaders(
          const <MapEntry<String, String>>[
            MapEntry<String, String>('cache-control', 'max-age=60'),
            MapEntry<String, String>('content-type', 'image/png'),
          ],
        );
        resultPointer.ref
          ..is_success = 1
          ..status_code = 201
          ..headers_ptr = headersPointer
          ..headers_len = 2
          ..final_url_ptr =
              'https://cdn.example.com/final.png'.toNativeUtf8().cast()
          ..final_url_len = 'https://cdn.example.com/final.png'.length
          ..error_json = ffi.nullptr;

        final bodyPointer = calloc<ffi.Uint8>(4);
        bodyPointer.asTypedList(4).setAll(0, const <int>[5, 6, 7, 8]);
        resultPointer.ref
          ..body_ptr = bodyPointer
          ..body_len = 4;

        callback.asFunction<
            void Function(int, ffi.Pointer<NexaHttpBinaryResult>)>()(
          requestId,
          resultPointer,
        );
        return 1;
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
    expect(
      response.headers,
      <String, List<String>>{
        'cache-control': <String>['max-age=60'],
        'content-type': <String>['image/png'],
      },
    );
    expect(response.bodyBytes, const <int>[5, 6, 7, 8]);
    expect(response.finalUri, Uri.parse('https://cdn.example.com/final.png'));
    expect(bindings.freedResultCount, 1);
  });
}

class _FakeNexaHttpBindings extends NexaHttpBindings {
  _FakeNexaHttpBindings({required this.onExecuteAsync})
      : super.fromLookup(_unimplementedLookup);

  final int Function({
    required int clientId,
    required int requestId,
    required _StructuredRequestWire? structuredRequest,
    required NexaHttpExecuteCallback callback,
  }) onExecuteAsync;

  int freedResultCount = 0;

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
  void nexa_http_binary_result_free(ffi.Pointer<NexaHttpBinaryResult> value) {
    freedResultCount += 1;
    if (value.ref.headers_ptr != ffi.nullptr && value.ref.headers_len > 0) {
      for (var index = 0; index < value.ref.headers_len; index += 1) {
        final entry = value.ref.headers_ptr.elementAt(index).ref;
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
