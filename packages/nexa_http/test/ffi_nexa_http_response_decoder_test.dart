// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';
import 'package:nexa_http/src/api/nexa_http_exception.dart';
import 'package:nexa_http/src/data/sources/ffi_nexa_http_response_decoder.dart';
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
      ..final_url_ptr = 'https://cdn.example.com/final.png'.toNativeUtf8().cast()
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
    expect(response.bodyBytes, const <int>[5, 6, 7, 8]);
    expect(response.finalUri, Uri.parse('https://cdn.example.com/final.png'));
    expect(freeCount, 0);
  });

  test('decodes structured native error payloads', () {
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
      ..error_json = '{"code":"timeout","message":"timed out","is_timeout":true}'
          .toNativeUtf8()
          .cast();

    final decoder = FfiNexaHttpResponseDecoder(
      releaseBinaryResult: (_) {},
      binaryResultNativeFinalizer: null,
    );

    expect(
      () => decoder.decode(resultPointer),
      throwsA(
        isA<NexaHttpException>()
            .having((error) => error.code, 'code', 'timeout')
            .having((error) => error.isTimeout, 'isTimeout', isTrue),
      ),
    );
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
