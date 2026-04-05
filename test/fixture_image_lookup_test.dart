import 'dart:io';

import 'package:test/test.dart';

import '../packages/nexa_http/test/support/http_fixture_server.dart';

void main() {
  test('fixture image exists at the repo-root lookup path', () {
    final file = File(
      'app/demo/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    );
    expect(file.existsSync(), isTrue);
  });

  test('repo-root fixture server serves the image endpoint', () async {
    final server = await HttpFixtureServer.start();
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final request = await client.getUrl(
      server.uri('/image', <String, String>{'id': 'root-check'}),
    );
    final response = await request.close();
    final body = await response.expand((chunk) => chunk).toList();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'image/png');
    expect(response.headers.value('x-fixture-image-id'), 'root-check');
    expect(body, isNotEmpty);
  });
}
