import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/nexa_http_platform.dart';
import 'package:test/test.dart';

void main() {
  test('exports the OkHttp-aligned NexaHttp public API surface', () async {
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/items'))
        .header('x-sdk', 'nexa_http')
        .get()
        .build();

    expect(request.method, 'GET');
    expect(request.url, Uri.parse('https://example.com/items'));
    expect(request.headers['x-sdk'], 'nexa_http');

    final requestBody = RequestBody.bytes(
      const <int>[1, 2, 3],
      contentType: MediaType.parse('application/octet-stream'),
    );
    final postRequest = RequestBuilder()
        .url(Uri.parse('https://example.com/upload'))
        .post(requestBody)
        .build();
    expect(postRequest.method, 'POST');
    expect(postRequest.body, same(requestBody));

    final responseBody = ResponseBody.fromString(
      'ok',
      contentType: MediaType.parse('text/plain; charset=utf-8'),
    );
    final response = Response(
      request: postRequest,
      statusCode: 200,
      headers: Headers.of(<String, List<String>>{
        'content-type': <String>['text/plain; charset=utf-8'],
      }),
      body: responseBody,
    );

    expect(response.isSuccessful, isTrue);
    expect(await response.body!.string(), 'ok');

    expect(NexaHttpClient, isA<Type>());
    expect(NexaHttpClientBuilder, isA<Type>());
    expect(Call, isA<Type>());
    expect(Callback, isA<Type>());
    expect(NexaHttpException, isA<Type>());

    expect(registerNexaHttpNativeRuntime, isA<Function>());
    expect(NexaHttpNativeRuntime, isA<Type>());
  });
}
