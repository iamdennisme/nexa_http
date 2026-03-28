import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('exports the NexaHttp public API surface', () async {
    expect(
      const NexaHttpClientConfig(
        defaultHeaders: <String, String>{'x-sdk': 'nexa_http'},
      ).defaultHeaders['x-sdk'],
      'nexa_http',
    );

    final request = NexaHttpRequest.get(uri: Uri.parse('https://example.com'));
    expect(request.method, NexaHttpMethod.get);

    final response = NexaHttpStreamedResponse(
      statusCode: 200,
      bodyStream: Stream<Uint8List>.value(Uint8List.fromList(<int>[1, 2])),
    );
    expect(response.statusCode, 200);
    expect(await response.readBytes(), orderedEquals(<int>[1, 2]));

    const exception = NexaHttpException(
      code: 'timeout',
      message: 'timed out',
      isTimeout: true,
    );
    expect(exception.isTimeout, isTrue);

    expect(NexaHttpClient, isA<Type>());
  });
}
