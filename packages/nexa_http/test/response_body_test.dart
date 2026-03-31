import 'dart:convert';
import 'dart:ffi';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/transport/native_response_body_bytes.dart';
import 'package:test/test.dart';

void main() {
  test('reads response body as bytes, string, and stream', () async {
    final body = ResponseBody.bytes(const <int>[
      104,
      105,
    ], contentType: MediaType.parse('text/plain; charset=utf-8'));

    final firstRead = await body.bytes();
    final secondRead = await body.bytes();
    final streamed = await body.byteStream().single;

    expect(firstRead, const <int>[104, 105]);
    expect(identical(firstRead, secondRead), isTrue);
    expect(identical(firstRead, streamed), isTrue);
    expect(await body.string(), 'hi');
  });

  test('rejects reads after the body is closed', () async {
    final body = ResponseBody.fromString('closed');

    body.close();

    expect(body.bytes(), throwsA(isA<StateError>()));
    expect(body.string(), throwsA(isA<StateError>()));
  });

  test(
    'fromString adopts freshly encoded bytes without an extra copy',
    () async {
      final encoding = _TrackingEncoding(<int>[120, 121]);

      final body = ResponseBody.fromString('xy', encoding: encoding);
      final bytes = await body.bytes();

      expect(identical(bytes, encoding.lastEncodedBytes), isTrue);
    },
  );

  test('close eagerly releases native-backed body bytes', () async {
    var releaseCount = 0;
    final body = adoptResponseBodyBytes(
      adoptNativeResponseBodyBytes(
        const <int>[1, 2, 3],
        release: () {
          releaseCount += 1;
        },
        finalizerToken: Pointer<Void>.fromAddress(1),
      ),
    );

    final bytes = await body.bytes();
    expect(bytes, const <int>[1, 2, 3]);

    body.close();

    expect(releaseCount, 1);
    expect(() => bytes[0], throwsA(isA<StateError>()));
    body.close();
    expect(releaseCount, 1);
  });
}

final class _TrackingEncoding extends Encoding {
  _TrackingEncoding(List<int> encodedBytes)
    : _encodedBytes = List<int>.unmodifiable(encodedBytes);

  final List<int> _encodedBytes;
  List<int>? lastEncodedBytes;

  @override
  String get name => 'tracking';

  @override
  Converter<List<int>, String> get decoder => utf8.decoder;

  @override
  Converter<String, List<int>> get encoder => _TrackingEncoder(this);
}

final class _TrackingEncoder extends Converter<String, List<int>> {
  const _TrackingEncoder(this._encoding);

  final _TrackingEncoding _encoding;

  @override
  List<int> convert(String input) {
    _encoding.lastEncodedBytes = _encoding._encodedBytes;
    return _encoding._encodedBytes;
  }
}
