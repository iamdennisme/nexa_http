import 'dart:convert';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('adopts the owned binary payload across reads and streams', () async {
    final payload = Uint8List.fromList(const <int>[1, 2, 3]);
    final body = RequestBody.bytes(payload);

    final firstRead = await body.bytes();
    final secondRead = await body.bytes();
    final streamed = await body.byteStream().single;

    expect(identical(firstRead, payload), isTrue);
    expect(identical(secondRead, payload), isTrue);
    expect(identical(streamed, payload), isTrue);
  });

  test('text adopts freshly encoded bytes without an extra copy', () async {
    final encoding = _TrackingEncoding(<int>[65, 66, 67]);

    final body = RequestBody.text('abc', encoding: encoding);
    final bytes = await body.bytes();

    expect(identical(bytes, encoding.lastEncodedBytes), isTrue);
  });

  test('text uses one canonical payload for reads and transport', () async {
    final body = RequestBody.text('abc');

    expect(body.payloadBytes, same(await body.bytes()));
    expect(body.payloadBytes, same(await body.byteStream().single));
  });
}

final class _TrackingEncoding extends Encoding {
  _TrackingEncoding(List<int> encodedBytes)
    : _encodedBytes = Uint8List.fromList(encodedBytes);

  final Uint8List _encodedBytes;
  Uint8List? lastEncodedBytes;

  @override
  String get name => 'tracking';

  @override
  Converter<List<int>, String> get decoder => utf8.decoder;

  @override
  Converter<String, List<int>> get encoder => _TrackingEncoder(this);
}

final class _TrackingEncoder extends Converter<String, Uint8List> {
  const _TrackingEncoder(this._encoding);

  final _TrackingEncoding _encoding;

  @override
  Uint8List convert(String input) {
    _encoding.lastEncodedBytes = _encoding._encodedBytes;
    return _encoding._encodedBytes;
  }
}
