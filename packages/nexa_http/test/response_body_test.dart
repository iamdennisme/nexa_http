import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/api/response_body.dart'
    show ResponseBodyTransportAccess;
import 'package:nexa_http/src/internal/body/response_body_owner.dart';
import 'package:test/test.dart';

void main() {
  test('buffered bytes are snapshotted once and consumed once', () async {
    final source = Uint8List.fromList(const <int>[104, 105]);
    final body = ResponseBody.bytes(
      source,
      contentType: MediaType.parse('text/plain; charset=utf-8'),
    );
    source[0] = 120;

    final bytes = await body.bytes();

    expect(bytes, isA<Uint8List>());
    expect(bytes, const <int>[104, 105]);
    await expectLater(body.bytes(), throwsA(isA<StateError>()));
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

  test('native bytes copies once and releases ownership once', () async {
    final nativeView = Uint8List.fromList(const <int>[1, 2, 3]);
    var copyCount = 0;
    var releaseCount = 0;
    Uint8List? copiedSource;
    final body = ResponseBodyTransportAccess.adopt(
      NativeResponseBodyOwner(
        nativeView,
        release: () {
          releaseCount += 1;
        },
      ),
      copyBytes: (source) {
        copyCount += 1;
        copiedSource = source;
        return Uint8List.fromList(source);
      },
    );

    final bytes = await body.bytes();

    expect(copyCount, 1);
    expect(copiedSource, same(nativeView));
    expect(bytes, const <int>[1, 2, 3]);
    expect(bytes, isNot(same(nativeView)));
    expect(releaseCount, 1);
    body.close();
    expect(releaseCount, 1);
  });

  test('native string decodes the original view without copying', () async {
    final nativeView = Uint8List.fromList(const <int>[104, 105]);
    var copyCount = 0;
    var decodeCount = 0;
    var releaseCount = 0;
    Uint8List? decodedSource;
    final body = ResponseBodyTransportAccess.adopt(
      NativeResponseBodyOwner(
        nativeView,
        release: () {
          releaseCount += 1;
        },
      ),
      copyBytes: (source) {
        copyCount += 1;
        return Uint8List.fromList(source);
      },
      decodeBytes: (encoding, source) {
        decodeCount += 1;
        decodedSource = source;
        return encoding.decode(source);
      },
    );

    expect(await body.string(), 'hi');
    expect(copyCount, 0);
    expect(decodeCount, 1);
    expect(decodedSource, same(nativeView));
    expect(releaseCount, 1);
    await expectLater(body.bytes(), throwsA(isA<StateError>()));
  });

  test('native decode failure still releases ownership once', () async {
    var releaseCount = 0;
    final body = ResponseBodyTransportAccess.adopt(
      NativeResponseBodyOwner(
        Uint8List.fromList(const <int>[255]),
        release: () {
          releaseCount += 1;
        },
      ),
      decodeBytes: (_, _) => throw const FormatException('invalid body'),
    );

    await expectLater(body.string(), throwsA(isA<FormatException>()));
    expect(releaseCount, 1);
    body.close();
    expect(releaseCount, 1);
  });

  test('Dart-owned and empty bodies do not copy during consumption', () async {
    for (final buffer in <Uint8List>[
      Uint8List.fromList(const <int>[7, 8, 9]),
      Uint8List(0),
    ]) {
      var copyCount = 0;
      final body = ResponseBodyTransportAccess.adopt(
        DartResponseBodyOwner(buffer),
        copyBytes: (source) {
          copyCount += 1;
          return Uint8List.fromList(source);
        },
      );

      final bytes = await body.bytes();
      expect(bytes, same(buffer));
      expect(copyCount, 0);
    }
  });

  test('close eagerly releases native-backed body bytes', () async {
    var releaseCount = 0;
    var copyCount = 0;
    final body = ResponseBodyTransportAccess.adopt(
      NativeResponseBodyOwner(
        Uint8List.fromList(const <int>[1, 2, 3]),
        release: () {
          releaseCount += 1;
        },
        finalizerToken: Pointer<Void>.fromAddress(1),
      ),
      copyBytes: (source) {
        copyCount += 1;
        return Uint8List.fromList(source);
      },
    );

    body.close();

    expect(releaseCount, 1);
    expect(copyCount, 0);
    body.close();
    expect(releaseCount, 1);
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
