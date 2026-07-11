import 'dart:convert';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/api/request_body.dart'
    show RequestBodyTransportAccess;
import 'package:test/test.dart';

void main() {
  test('takeBytes transfers the original Uint8List without copying', () {
    final payload = Uint8List.fromList(const <int>[1, 2, 3]);
    final body = RequestBody.takeBytes(payload);

    expect(RequestBodyTransportAccess.bytes(body), same(payload));
  });

  test('text adopts freshly encoded Uint8List without an extra copy', () {
    final encoding = _TrackingEncoding(<int>[65, 66, 67]);

    final body = RequestBody.text('abc', encoding: encoding);
    final bytes = RequestBodyTransportAccess.bytes(body);

    expect(identical(bytes, encoding.lastEncodedBytes), isTrue);
  });

  test('text normalizes a generic byte list once', () {
    final encoding = _GenericTrackingEncoding(<int>[65, 66, 67]);

    final body = RequestBody.text('abc', encoding: encoding);
    final bytes = RequestBodyTransportAccess.bytes(body);

    expect(bytes, isA<Uint8List>());
    expect(bytes, const <int>[65, 66, 67]);
    expect(encoding.encodeCount, 1);
  });
}

final class _GenericTrackingEncoding extends Encoding {
  _GenericTrackingEncoding(this._encodedBytes);

  final List<int> _encodedBytes;
  int encodeCount = 0;

  @override
  String get name => 'generic-tracking';

  @override
  Converter<List<int>, String> get decoder => utf8.decoder;

  @override
  Converter<String, List<int>> get encoder => _GenericTrackingEncoder(this);
}

final class _GenericTrackingEncoder extends Converter<String, List<int>> {
  const _GenericTrackingEncoder(this._encoding);

  final _GenericTrackingEncoding _encoding;

  @override
  List<int> convert(String input) {
    _encoding.encodeCount += 1;
    return _encoding._encodedBytes;
  }
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
