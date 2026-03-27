import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/nexa_http_dio.dart';
import 'package:test/test.dart';

void main() {
  test('exports the NexaHttp public API surface', () {
    expect(
      const NexaHttpClientConfig(
        defaultHeaders: <String, String>{'x-sdk': 'nexa_http'},
      ).defaultHeaders['x-sdk'],
      'nexa_http',
    );

    final request = NexaHttpRequest.get(uri: Uri.parse('https://example.com'));
    expect(request.method, NexaHttpMethod.get);

    const response = NexaHttpResponse(statusCode: 200);
    expect(response.isSuccessful, isTrue);

    const exception = NexaHttpException(
      code: 'timeout',
      message: 'timed out',
      isTimeout: true,
    );
    expect(exception.isTimeout, isTrue);

    expect(NexaHttpClient, isA<Type>());
    expect(NexaHttpDioAdapter, isA<Type>());
  });
}
