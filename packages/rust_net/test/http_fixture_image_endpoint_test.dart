import 'dart:io';

import 'support/http_fixture_server.dart';
import 'package:test/test.dart';

void main() {
  test('image endpoint serves a cacheable PNG fixture', () async {
    final server = await HttpFixtureServer.start();
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final request = await client.getUrl(
      server.uri(
        '/image',
        <String, String>{'id': 'poster-1'},
      ),
    );
    final response = await request.close();
    final body = await response.expand((chunk) => chunk).toList();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'image/png');
    expect(response.headers.value(HttpHeaders.cacheControlHeader), 'max-age=60');
    expect(response.headers.value('x-fixture-image-id'), 'poster-1');
    expect(body, isNotEmpty);
  });
}
