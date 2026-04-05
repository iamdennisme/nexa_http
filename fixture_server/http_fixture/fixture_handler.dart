import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final class FixtureHandler {
  const FixtureHandler._();

  static const allowMethods = 'GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS';
  static Future<List<int>>? _cachedFixtureImageBytes;

  static Future<void> handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('x-rust-net-fixture', 'true');

    final method = request.method.toUpperCase();
    final path = request.uri.path;

    if (path == '/healthz' && (method == 'GET' || method == 'HEAD')) {
      _writeText(
        request: request,
        statusCode: HttpStatus.ok,
        text: 'ok',
        extraHeaders: const <String, Object>{'x-fixture-healthz': 'true'},
      );
      return;
    }

    if (path == '/get' && method == 'GET') {
      _writeJson(
        request: request,
        statusCode: HttpStatus.ok,
        payload: <String, Object?>{
          'message': 'hello from fixture',
          'method': method,
          'path': path,
          'query': request.uri.queryParameters,
        },
      );
      return;
    }

    if (path == '/echo' &&
        (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
      final bodyBytes = await _readBodyBytes(request);
      response
        ..statusCode = method == 'POST' ? HttpStatus.created : HttpStatus.ok
        ..headers.contentType =
            request.headers.contentType ?? ContentType.binary
        ..headers.set('x-request-method', method)
        ..add(bodyBytes);
      await response.close();
      return;
    }

    if (path == '/redirect-target') {
      final bodyBytes = await _readBodyBytes(request);
      _writeJson(
        request: request,
        statusCode: HttpStatus.ok,
        payload: <String, Object?>{
          'method': method,
          'path': path,
          'query': request.uri.queryParameters,
          'body_text': utf8.decode(bodyBytes, allowMalformed: true),
        },
      );
      return;
    }

    if (path == '/delete' && method == 'DELETE') {
      _writeJson(
        request: request,
        statusCode: HttpStatus.ok,
        payload: <String, Object?>{
          'deleted': true,
          'method': method,
          'path': path,
        },
      );
      return;
    }

    if (path == '/head' && method == 'HEAD') {
      response
        ..statusCode = HttpStatus.ok
        ..headers.set('x-fixture-head', 'true');
      await response.close();
      return;
    }

    if (path == '/options' && method == 'OPTIONS') {
      response
        ..statusCode = HttpStatus.noContent
        ..headers.set(HttpHeaders.allowHeader, allowMethods);
      await response.close();
      return;
    }

    if (path == '/slow' && method == 'GET') {
      final delayMs =
          int.tryParse(request.uri.queryParameters['delay_ms'] ?? '') ?? 250;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      _writeJson(
        request: request,
        statusCode: HttpStatus.ok,
        payload: <String, Object>{'delayed_ms': delayMs},
      );
      return;
    }

    if (path == '/bytes' && method == 'GET') {
      final size =
          int.tryParse(request.uri.queryParameters['size'] ?? '') ?? 65536;
      final seed = int.tryParse(request.uri.queryParameters['seed'] ?? '') ?? 0;
      final payload = Uint8List.fromList(
        List<int>.generate(size, (index) => (seed + index) % 256),
      );
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.binary
        ..headers.set('x-fixture-size', '$size')
        ..headers.set('x-fixture-seed', '$seed')
        ..add(payload);
      await response.close();
      return;
    }

    if (path == '/image' && method == 'GET') {
      final imageId = request.uri.queryParameters['id'] ?? 'image-0';
      final bodyBytes = await _fixtureImageBytes();
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'png')
        ..headers.set(HttpHeaders.cacheControlHeader, 'max-age=60')
        ..headers.set('x-fixture-image-id', imageId)
        ..add(bodyBytes);
      await response.close();
      return;
    }

    if (_isStatusPath(path)) {
      final statusCode = int.parse(path.split('/').last);
      _writeStatusResponse(
        request: request,
        statusCode: statusCode,
      );
      return;
    }

    if (_isRedirectPath(path)) {
      final statusCode = int.parse(path.split('/').last);
      final location = request.uri.queryParameters['location'] ??
          '/redirect-target?source=redirected';
      response
        ..statusCode = statusCode
        ..headers.set(HttpHeaders.locationHeader, location);
      await response.close();
      return;
    }

    _writeJson(
      request: request,
      statusCode: HttpStatus.notFound,
      payload: <String, Object?>{
        'error': 'Not Found',
        'method': method,
        'path': path,
      },
    );
  }

  static bool _isStatusPath(String path) {
    final match = RegExp(r'^/status/\d{3}$').hasMatch(path);
    return match;
  }

  static bool _isRedirectPath(String path) {
    final match = RegExp(r'^/redirect/(301|302|303|307|308)$').hasMatch(path);
    return match;
  }

  static void _writeStatusResponse({
    required HttpRequest request,
    required int statusCode,
  }) {
    final response = request.response;
    response.statusCode = statusCode;

    final disallowBody = request.method.toUpperCase() == 'HEAD' ||
        statusCode == HttpStatus.noContent ||
        statusCode == HttpStatus.notModified;
    if (disallowBody) {
      response.close();
      return;
    }

    response.headers.contentType = ContentType.json;
    response.write(
      jsonEncode(<String, Object?>{
        'status_code': statusCode,
        'method': request.method.toUpperCase(),
        'path': request.uri.path,
      }),
    );
    response.close();
  }

  static void _writeJson({
    required HttpRequest request,
    required int statusCode,
    required Map<String, Object?> payload,
  }) {
    final response = request.response;
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json;
    if (request.method.toUpperCase() != 'HEAD') {
      response.write(jsonEncode(payload));
    }
    response.close();
  }

  static void _writeText({
    required HttpRequest request,
    required int statusCode,
    required String text,
    Map<String, Object>? extraHeaders,
  }) {
    final response = request.response;
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.text;
    extraHeaders?.forEach(response.headers.set);
    if (request.method.toUpperCase() != 'HEAD') {
      response.write(text);
    }
    response.close();
  }

  static Future<Uint8List> _readBodyBytes(HttpRequest request) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Future<List<int>> _fixtureImageBytes() {
    return _cachedFixtureImageBytes ??=
        _loadFixtureImageBytes();
  }

  static Future<List<int>> _loadFixtureImageBytes() async {
    final candidates = <String>[
      'app/demo/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
      'app/demo/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
      'example/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    throw StateError('Fixture image asset could not be found from $candidates');
  }
}
