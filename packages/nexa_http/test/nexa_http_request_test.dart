import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('builds a POST request with headers, body, and timeout', () async {
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/items'))
        .header('content-type', 'application/json')
        .timeout(const Duration(seconds: 5))
        .post(
          RequestBody.bytes(
            Uint8List.fromList(const <int>[1, 2, 3]),
            contentType: MediaType.parse('application/json'),
          ),
        )
        .build();

    expect(request.method, 'POST');
    expect(request.url, Uri.parse('https://example.com/items'));
    expect(request.headers['content-type'], 'application/json');
    expect(request.timeout, const Duration(seconds: 5));
    expect(await request.body!.bytes(), const <int>[1, 2, 3]);
  });

  test('newBuilder clones a request for targeted mutation', () {
    final original = RequestBuilder()
        .url(Uri.parse('https://example.com/items/42'))
        .header('x-sdk', 'nexa_http')
        .put(RequestBody.bytes(Uint8List.fromList(const <int>[4, 5, 6])))
        .timeout(const Duration(seconds: 3))
        .build();

    final updated = original
        .newBuilder()
        .url(Uri.parse('https://example.com/items/43'))
        .build();

    expect(updated.method, 'PUT');
    expect(updated.url, Uri.parse('https://example.com/items/43'));
    expect(updated.headers['x-sdk'], 'nexa_http');
    expect(updated.timeout, const Duration(seconds: 3));
    expect(updated.body, same(original.body));
  });
}
