import 'dart:convert';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('reuses the stored immutable bytes across reads and streams', () async {
    final body = RequestBody.bytes(const <int>[1, 2, 3]);

    final firstRead = await body.bytes();
    final secondRead = await body.bytes();
    final streamed = await body.byteStream().single;

    expect(identical(firstRead, body.bytesValue), isTrue);
    expect(identical(secondRead, body.bytesValue), isTrue);
    expect(identical(streamed, body.bytesValue), isTrue);
  });

  test(
    'fromString adopts freshly encoded bytes without an extra copy',
    () async {
      final encoding = _TrackingEncoding(<int>[65, 66, 67]);

      final body = RequestBody.fromString('abc', encoding: encoding);
      final bytes = await body.bytes();

      expect(identical(bytes, encoding.lastEncodedBytes), isTrue);
    },
  );
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
