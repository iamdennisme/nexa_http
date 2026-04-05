import 'dart:async';
import 'dart:io';

import 'package:nexa_http/nexa_http.dart';

import 'benchmark_models.dart';

final class BenchmarkRunner {
  const BenchmarkRunner();

  Uri buildRequestUri({
    required BenchmarkConfig config,
    required int requestIndex,
  }) {
    final baseUri = Uri.parse(config.baseUrl);
    switch (config.scenario) {
      case BenchmarkScenario.bytes:
        return baseUri.replace(
          path: '/bytes',
          queryParameters: <String, String>{
            'size': '${config.payloadSize}',
            'seed': '$requestIndex',
          },
        );
      case BenchmarkScenario.image:
        return baseUri.replace(
          path: '/image',
          queryParameters: <String, String>{'id': 'image-$requestIndex'},
        );
    }
  }

  Future<BenchmarkMetrics> run({
    required BenchmarkConfig config,
    required BenchmarkTransport transport,
  }) async {
    try {
      final firstRequestUri = buildRequestUri(config: config, requestIndex: 0);
      final firstRequestStopwatch = Stopwatch()..start();
      try {
        await transport.fetch(uri: firstRequestUri, timeout: config.timeout);
      } catch (_) {
        // Cold-start failures should not abort the measured run.
      } finally {
        firstRequestStopwatch.stop();
      }

      for (var index = 1; index <= config.warmupRequests; index += 1) {
        final uri = buildRequestUri(config: config, requestIndex: index);
        try {
          await transport.fetch(uri: uri, timeout: config.timeout);
        } catch (_) {
          // Warmup should not abort the measured run.
        }
      }

      var nextRequestIndex = config.warmupRequests + 1;
      final measuredRequestEnd = nextRequestIndex + config.totalRequests;
      final samples = <BenchmarkSample>[];
      final stopwatch = Stopwatch()..start();

      Future<void> worker() async {
        while (true) {
          final requestIndex = nextRequestIndex;
          if (requestIndex >= measuredRequestEnd) {
            return;
          }
          nextRequestIndex += 1;

          final uri = buildRequestUri(
            config: config,
            requestIndex: requestIndex,
          );
          final latency = Stopwatch()..start();

          try {
            final result = await transport.fetch(
              uri: uri,
              timeout: config.timeout,
            );
            latency.stop();
            samples.add(
              BenchmarkSample(
                latency: latency.elapsed,
                bytesReceived: result.bytesReceived,
                isSuccess: result.statusCode >= 200 && result.statusCode < 300,
                statusCode: result.statusCode,
              ),
            );
          } catch (error) {
            latency.stop();
            samples.add(
              BenchmarkSample(
                latency: latency.elapsed,
                bytesReceived: 0,
                isSuccess: false,
                errorMessage: '$error',
              ),
            );
          }
        }
      }

      await Future.wait(
        List<Future<void>>.generate(config.concurrency, (_) => worker()),
      );
      stopwatch.stop();

      return BenchmarkMetrics.fromSamples(
        transportLabel: transport.label,
        totalDuration: stopwatch.elapsed,
        firstRequestLatency: firstRequestStopwatch.elapsed,
        samples: samples,
      );
    } finally {
      await transport.close();
    }
  }
}

final class BenchmarkFetchResult {
  const BenchmarkFetchResult({
    required this.statusCode,
    required this.bytesReceived,
  });

  final int statusCode;
  final int bytesReceived;
}

abstract interface class BenchmarkTransport {
  String get label;

  Future<BenchmarkFetchResult> fetch({
    required Uri uri,
    required Duration timeout,
  });

  Future<void> close();
}

final class NexaHttpBenchmarkTransport implements BenchmarkTransport {
  NexaHttpBenchmarkTransport({required NexaHttpClient client})
    : _client = client;

  final NexaHttpClient _client;

  @override
  String get label => 'nexa_http';

  @override
  Future<BenchmarkFetchResult> fetch({
    required Uri uri,
    required Duration timeout,
  }) async {
    final request = RequestBuilder()
      ..url(uri)
      ..timeout(timeout)
      ..get();

    final response = await _client.newCall(request.build()).execute();
    final bytes = response.body == null
        ? const <int>[]
        : await response.body!.bytes();

    return BenchmarkFetchResult(
      statusCode: response.statusCode,
      bytesReceived: bytes.length,
    );
  }

  @override
  Future<void> close() async {
    await _client.close();
  }
}

final class DartHttpClientBenchmarkTransport implements BenchmarkTransport {
  DartHttpClientBenchmarkTransport() : _client = HttpClient();

  final HttpClient _client;

  @override
  String get label => 'Dart HttpClient';

  @override
  Future<BenchmarkFetchResult> fetch({
    required Uri uri,
    required Duration timeout,
  }) async {
    final request = await _client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    var bytesReceived = 0;
    await for (final chunk in response.timeout(timeout)) {
      bytesReceived += chunk.length;
    }

    return BenchmarkFetchResult(
      statusCode: response.statusCode,
      bytesReceived: bytesReceived,
    );
  }

  @override
  Future<void> close() async {
    _client.close(force: true);
  }
}
