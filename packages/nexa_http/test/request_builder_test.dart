import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('builds a GET request with fluent builder verbs', () {
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/healthz'))
        .header('x-trace-id', 'abc-123')
        .get()
        .build();

    expect(request.method, 'GET');
    expect(request.url, Uri.parse('https://example.com/healthz'));
    expect(request.headers['x-trace-id'], 'abc-123');
    expect(request.body, isNull);
  });

  test('builds a POST request with a request body', () async {
    final body = RequestBody.bytes(
      const <int>[1, 2, 3],
      contentType: MediaType.parse('application/octet-stream'),
    );

    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/items'))
        .post(body)
        .build();

    expect(request.method, 'POST');
    expect(request.url, Uri.parse('https://example.com/items'));
    expect(request.body, same(body));
    expect(request.body!.contentType.toString(), 'application/octet-stream');
    expect(await request.body!.bytes(), const <int>[1, 2, 3]);
  });
}
