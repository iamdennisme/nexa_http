import 'package:nexa_http/nexa_http.dart';
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

    final postRequest = NexaHttpRequest.post(
      uri: Uri.parse('https://example.com/items'),
      bodyBytes: const <int>[1, 2, 3],
    );
    expect(postRequest.method, NexaHttpMethod.post);

    final putRequest = NexaHttpRequest.put(
      uri: Uri.parse('https://example.com/items/42'),
      bodyBytes: const <int>[4, 5, 6],
    );
    expect(putRequest.method, NexaHttpMethod.put);

    expect(NexaHttpClient, isA<Type>());
  });
}
