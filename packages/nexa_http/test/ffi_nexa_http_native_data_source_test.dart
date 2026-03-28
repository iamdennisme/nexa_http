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
        required String requestJson,
        required Uint8List bodyBytes,
        required NexaHttpExecuteCallback callback,
      }) {
        expect(clientId, 7);
        expect(requestJson, isEmpty);
        expect(bodyBytes, Uint8List.fromList(const <int>[1, 2, 3, 4]));

        final resultPointer = calloc<NexaHttpBinaryResult>();
        resultPointer.ref
          ..is_success = 1
          ..status_code = 200
          ..headers_json = ffi.nullptr
          ..final_url = 'https://example.com/upload'.toNativeUtf8().cast()
          ..error_json = ffi.nullptr;

        final bodyPointer = calloc<ffi.Uint8>(3);
        bodyPointer.asTypedList(3).setAll(0, const <int>[9, 8, 7]);
        resultPointer.ref
          ..body_ptr = bodyPointer
          ..body_len = 3;

        callback
            .asFunction<void Function(int, ffi.Pointer<NexaHttpBinaryResult>)>()(
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
        required String requestJson,
        required Uint8List bodyBytes,
        required NexaHttpExecuteCallback callback,
      }) {
        expect(clientId, 9);

        final resultPointer = calloc<NexaHttpBinaryResult>();
        resultPointer.ref
          ..is_success = 1
          ..status_code = 201
          ..headers_json = ffi.nullptr
          ..final_url = 'https://cdn.example.com/final.png'.toNativeUtf8().cast()
          ..error_json = ffi.nullptr;

        final bodyPointer = calloc<ffi.Uint8>(4);
        bodyPointer.asTypedList(4).setAll(0, const <int>[5, 6, 7, 8]);
        resultPointer.ref
          ..body_ptr = bodyPointer
          ..body_len = 4;

        callback
            .asFunction<void Function(int, ffi.Pointer<NexaHttpBinaryResult>)>()(
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
    required String requestJson,
    required Uint8List bodyBytes,
    required NexaHttpExecuteCallback callback,
  }) onExecuteAsync;

  int freedResultCount = 0;

  @override
  int nexa_http_client_execute_async(
    int client_id,
    int request_id,
    ffi.Pointer<ffi.Char> request_json,
    ffi.Pointer<ffi.Uint8> body_ptr,
    int body_len,
    NexaHttpExecuteCallback callback,
  ) {
    return onExecuteAsync(
      clientId: client_id,
      requestId: request_id,
      requestJson: request_json.cast<Utf8>().toDartString(),
      bodyBytes: body_ptr == ffi.nullptr
          ? Uint8List(0)
          : Uint8List.fromList(body_ptr.asTypedList(body_len)),
      callback: callback,
    );
  }

  @override
  void nexa_http_binary_result_free(ffi.Pointer<NexaHttpBinaryResult> value) {
    freedResultCount += 1;
    if (value.ref.headers_json != ffi.nullptr) {
      calloc.free(value.ref.headers_json.cast<Utf8>());
    }
    if (value.ref.final_url != ffi.nullptr) {
      calloc.free(value.ref.final_url.cast<Utf8>());
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
