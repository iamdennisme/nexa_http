import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'http_fixture/fixture_handler.dart';

Future<void> main(List<String> arguments) async {
  final port = _parsePort(arguments) ?? 8080;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

  stdout.writeln(
    jsonEncode(<String, Object>{
      'base_url': 'http://${server.address.address}:${server.port}',
      'pid': pid,
    }),
  );

  final shutdown = Completer<void>();
  ProcessSignal.sigint.watch().listen((_) async {
    if (!shutdown.isCompleted) {
      shutdown.complete();
    }
  });
  ProcessSignal.sigterm.watch().listen((_) async {
    if (!shutdown.isCompleted) {
      shutdown.complete();
    }
  });

  unawaited(
    server.forEach((request) async {
      try {
        await FixtureHandler.handle(request);
      } catch (error, stackTrace) {
        stderr.writeln('fixture-server error: $error');
        stderr.writeln(stackTrace);
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{
            'error': '$error',
          }));
        await request.response.close();
      }
    }),
  );

  await shutdown.future;
  await server.close(force: true);
}

int? _parsePort(List<String> arguments) {
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--port' && index + 1 < arguments.length) {
      return int.tryParse(arguments[index + 1]);
    }
    if (argument.startsWith('--port=')) {
      return int.tryParse(argument.substring('--port='.length));
    }
  }
  return null;
}
