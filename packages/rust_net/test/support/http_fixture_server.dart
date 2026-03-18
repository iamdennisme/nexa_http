import 'dart:async';
import 'dart:io';

import '../../../../fixture_server/http_fixture/fixture_handler.dart';

final class HttpFixtureServer {
  HttpFixtureServer._(this._server);

  final HttpServer _server;

  static Future<HttpFixtureServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixtureServer = HttpFixtureServer._(server);
    unawaited(server.forEach(fixtureServer._handleRequest));
    return fixtureServer;
  }

  Uri uri(String path, [Map<String, String>? queryParameters]) {
    return Uri(
      scheme: 'http',
      host: _server.address.address,
      port: _server.port,
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    await FixtureHandler.handle(request);
  }
}
