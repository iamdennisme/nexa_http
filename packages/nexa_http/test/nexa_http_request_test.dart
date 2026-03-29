import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('post helper creates a POST request with body bytes', () {
    final request = NexaHttpRequest.post(
      uri: Uri.parse('https://example.com/items'),
      headers: const <String, String>{'content-type': 'application/json'},
      bodyBytes: const <int>[1, 2, 3],
      timeout: const Duration(seconds: 5),
    );

    expect(request.method, NexaHttpMethod.post);
    expect(request.uri, Uri.parse('https://example.com/items'));
    expect(request.headers, const <String, String>{
      'content-type': 'application/json',
    });
    expect(request.bodyBytes, const <int>[1, 2, 3]);
    expect(request.timeout, const Duration(seconds: 5));
  });

  test('put helper creates a PUT request with body bytes', () {
    final request = NexaHttpRequest.put(
      uri: Uri.parse('https://example.com/items/42'),
      headers: const <String, String>{'x-sdk': 'nexa_http'},
      bodyBytes: const <int>[4, 5, 6],
      timeout: const Duration(seconds: 3),
    );

    expect(request.method, NexaHttpMethod.put);
    expect(request.uri, Uri.parse('https://example.com/items/42'));
    expect(request.headers, const <String, String>{'x-sdk': 'nexa_http'});
    expect(request.bodyBytes, const <int>[4, 5, 6]);
    expect(request.timeout, const Duration(seconds: 3));
  });
}
