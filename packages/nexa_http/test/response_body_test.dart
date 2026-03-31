import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('reads response body as bytes, string, and stream', () async {
    final body = ResponseBody.bytes(
      const <int>[104, 105],
      contentType: MediaType.parse('text/plain; charset=utf-8'),
    );

    expect(await body.bytes(), const <int>[104, 105]);
    expect(await body.string(), 'hi');
    await expectLater(
      body.byteStream(),
      emitsInOrder(<Object>[
        const <int>[104, 105],
        emitsDone,
      ]),
    );
  });

  test('rejects reads after the body is closed', () async {
    final body = ResponseBody.fromString('closed');

    body.close();

    expect(body.bytes(), throwsA(isA<StateError>()));
    expect(body.string(), throwsA(isA<StateError>()));
  });
}
