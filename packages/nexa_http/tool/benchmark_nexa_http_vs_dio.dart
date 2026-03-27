import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nexa_http/nexa_http_dio.dart';

import '../test/support/http_fixture_server.dart';

Future<void> main() async {
  final fixtureServer = await HttpFixtureServer.start();
  final baseUrl = fixtureServer.uri('').replace(path: '').toString();

  final directDio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      responseType: ResponseType.bytes,
    ),
  );
  final rustNetDio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      responseType: ResponseType.bytes,
    ),
  )..httpClientAdapter = NexaHttpDioAdapter.client(
      config: const NexaHttpClientConfig(
        timeout: Duration(seconds: 10),
        userAgent: 'nexa_http_benchmark/1.0.0',
      ),
    );

  try {
    const concurrency = 50;
    const bytesPerRequest = 64 * 1024;

    final direct = await _runScenario(
      dio: directDio,
      concurrency: concurrency,
      bytesPerRequest: bytesPerRequest,
      label: 'dio',
    );
    final rustNet = await _runScenario(
      dio: rustNetDio,
      concurrency: concurrency,
      bytesPerRequest: bytesPerRequest,
      label: 'nexa_http',
    );

    final deltaMs =
        rustNet.elapsed.inMilliseconds - direct.elapsed.inMilliseconds;
    final deltaPercent = direct.elapsed.inMicroseconds == 0
        ? 0
        : ((rustNet.elapsed.inMicroseconds - direct.elapsed.inMicroseconds) /
                direct.elapsed.inMicroseconds) *
            100;

    stdout.writeln('Benchmark base URL: $baseUrl');
    stdout.writeln(direct.describe());
    stdout.writeln(rustNet.describe());
    stdout.writeln(
      'delta: ${deltaMs}ms (${deltaPercent.toStringAsFixed(2)}%) '
      'nexa_http vs dio',
    );
  } finally {
    directDio.close(force: true);
    rustNetDio.close(force: true);
    await fixtureServer.close();
  }
}

Future<_BenchmarkResult> _runScenario({
  required Dio dio,
  required int concurrency,
  required int bytesPerRequest,
  required String label,
}) async {
  final stopwatch = Stopwatch()..start();
  var totalBytes = 0;

  final responses = await Future.wait(
    List<Future<Response<List<int>>>>.generate(concurrency, (index) {
      return dio.get<List<int>>(
        '/bytes',
        queryParameters: <String, String>{
          'size': '$bytesPerRequest',
          'seed': '$index',
        },
      );
    }),
  );

  for (final response in responses) {
    final data = response.data ?? const <int>[];
    totalBytes += data.length;
  }

  stopwatch.stop();
  return _BenchmarkResult(
    label: label,
    elapsed: stopwatch.elapsed,
    totalBytes: totalBytes,
    requests: concurrency,
  );
}

final class _BenchmarkResult {
  const _BenchmarkResult({
    required this.label,
    required this.elapsed,
    required this.totalBytes,
    required this.requests,
  });

  final String label;
  final Duration elapsed;
  final int totalBytes;
  final int requests;

  String describe() {
    final megabytes = totalBytes / (1024 * 1024);
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final throughput = seconds == 0 ? 0 : megabytes / seconds;
    return '$label: requests=$requests bytes=$totalBytes '
        'elapsed=${elapsed.inMilliseconds}ms '
        'throughput=${throughput.toStringAsFixed(2)} MiB/s';
  }
}
