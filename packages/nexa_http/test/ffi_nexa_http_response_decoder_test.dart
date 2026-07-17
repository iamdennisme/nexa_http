// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:nexa_http/src/api/nexa_http_exception.dart';
import 'package:nexa_http/src/internal/native_transport/ffi_nexa_http_response_decoder.dart';
import 'package:nexa_http/src/internal/body/response_body_owner.dart';
import 'package:test/test.dart';

void main() {
  test('decodes structured native response metadata without header json', () {
    var freeCount = 0;
    final resultPointer = calloc<NexaHttpBinaryResult>();
    final headersPointer = _allocateHeaders(const <MapEntry<String, String>>[
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

    final decoder = FfiNexaHttpResponseDecoder(
      releaseBinaryResult: (_) {
        freeCount += 1;
      },
      binaryResultNativeFinalizer: null,
    );

    final response = decoder.decode(resultPointer);

    expect(response.statusCode, 201);
    expect(response.headers, <String, List<String>>{
      'cache-control': <String>['max-age=60'],
      'content-type': <String>['image/png'],
    });
    expect(response.bodyOwner, isA<ResponseBodyOwner>());
    expect(response.bodyOwner!.isNative, isTrue);
    expect(response.bodyOwner!.view, const <int>[5, 6, 7, 8]);
    bodyPointer.asTypedList(4)[0] = 9;
    expect(response.bodyOwner!.view[0], 9);
    expect(response.finalUri, Uri.parse('https://cdn.example.com/final.png'));
    expect(freeCount, 0);
    response.bodyOwner!.release();
    expect(freeCount, 1);
  });

  test('decodes structured native error payloads', () {
    var freeCount = 0;
    final resultPointer = calloc<NexaHttpBinaryResult>();
    resultPointer.ref
      ..is_success = 0
      ..status_code = 0
      ..headers_ptr = ffi.nullptr
      ..headers_len = 0
      ..final_url_ptr = ffi.nullptr
      ..final_url_len = 0
      ..body_ptr = ffi.nullptr
      ..body_len = 0
      ..error_json =
          '{"code":"timeout","message":"timed out","is_timeout":true}'
              .toNativeUtf8()
              .cast();

    final decoder = FfiNexaHttpResponseDecoder(
      releaseBinaryResult: (_) {
        freeCount += 1;
      },
      binaryResultNativeFinalizer: null,
    );

    expect(
      () => decoder.decode(resultPointer),
      throwsA(
        isA<NexaHttpException>().having(
          (error) => error.kind,
          'kind',
          NexaHttpFailureKind.timeout,
        ),
      ),
    );
    expect(freeCount, 1);
  });

  test('releases empty native results and returns a Dart-owned body', () {
    var freeCount = 0;
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
    final decoder = FfiNexaHttpResponseDecoder(
      releaseBinaryResult: (_) {
        freeCount += 1;
      },
      binaryResultNativeFinalizer: null,
    );

    final response = decoder.decode(resultPointer);

    expect(response.statusCode, 204);
    expect(response.bodyOwner!.isNative, isFalse);
    expect(response.bodyOwner!.view, isEmpty);
    expect(freeCount, 1);
    response.bodyOwner!.release();
    expect(freeCount, 1);
  });

  test('normalizes malformed native error payloads to internal', () {
    final errorJson = '{"code":'.toNativeUtf8();
    final resultPointer = calloc<NexaHttpBinaryResult>();
    resultPointer.ref
      ..is_success = 0
      ..status_code = 0
      ..headers_ptr = ffi.nullptr
      ..headers_len = 0
      ..final_url_ptr = ffi.nullptr
      ..final_url_len = 0
      ..body_ptr = ffi.nullptr
      ..body_len = 0
      ..error_json = errorJson.cast();

    final decoder = FfiNexaHttpResponseDecoder(
      releaseBinaryResult: (_) {},
      binaryResultNativeFinalizer: null,
    );

    expect(
      () => decoder.decode(resultPointer),
      throwsA(
        isA<NexaHttpException>()
            .having((error) => error.kind, 'kind', NexaHttpFailureKind.internal)
            .having(
              (error) => error.diagnostics?['stage'],
              'diagnostics.stage',
              'response_error_decode',
            ),
      ),
    );

    calloc
      ..free(errorJson)
      ..free(resultPointer);
  });

  test('normalizes an invalid native final URL to internal', () {
    final finalUrl = 'http://['.toNativeUtf8();
    final resultPointer = calloc<NexaHttpBinaryResult>();
    resultPointer.ref
      ..is_success = 1
      ..status_code = 200
      ..headers_ptr = ffi.nullptr
      ..headers_len = 0
      ..final_url_ptr = finalUrl.cast()
      ..final_url_len = 'http://['.length
      ..body_ptr = ffi.nullptr
      ..body_len = 0
      ..error_json = ffi.nullptr;

    final decoder = FfiNexaHttpResponseDecoder(
      releaseBinaryResult: (_) {},
      binaryResultNativeFinalizer: null,
    );

    expect(
      () => decoder.decode(resultPointer),
      throwsA(
        isA<NexaHttpException>()
            .having((error) => error.kind, 'kind', NexaHttpFailureKind.internal)
            .having(
              (error) => error.diagnostics?['stage'],
              'diagnostics.stage',
              'response_final_url_decode',
            ),
      ),
    );

    calloc
      ..free(finalUrl)
      ..free(resultPointer);
  });
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
