import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/main.dart';
import 'package:nexa_http_example/src/benchmark/benchmark_models.dart';
import 'package:nexa_http_example/src/benchmark/benchmark_runner.dart';

void main() {
  group('BenchmarkRunner', () {
    test('builds unique byte request URIs from config', () {
      const config = BenchmarkConfig(
        baseUrl: 'http://127.0.0.1:8080',
        scenario: BenchmarkScenario.bytes,
        concurrency: 4,
        totalRequests: 3,
        payloadSize: 2048,
        warmupRequests: 1,
        timeoutMillis: 3000,
      );

      final runner = BenchmarkRunner();
      final uris = List<Uri>.generate(
        config.totalRequests,
        (index) => runner.buildRequestUri(config: config, requestIndex: index),
      );

      expect(uris, hasLength(3));
      expect(uris[0].path, '/bytes');
      expect(uris[0].queryParameters['size'], '2048');
      expect(uris[0].queryParameters['seed'], '0');
      expect(uris[1].queryParameters['seed'], '1');
      expect(uris[2].queryParameters['seed'], '2');
    });

    test('builds unique image request URIs from config', () {
      const config = BenchmarkConfig(
        baseUrl: 'http://127.0.0.1:8080',
        scenario: BenchmarkScenario.image,
        concurrency: 2,
        totalRequests: 2,
        payloadSize: 4096,
        warmupRequests: 0,
        timeoutMillis: 3000,
      );

      final runner = BenchmarkRunner();
      final first = runner.buildRequestUri(config: config, requestIndex: 0);
      final second = runner.buildRequestUri(config: config, requestIndex: 1);

      expect(first.path, '/image');
      expect(second.path, '/image');
      expect(first.queryParameters['id'], 'image-0');
      expect(second.queryParameters['id'], 'image-1');
    });

    test(
      'captures first-request latency separately and keeps measured totals stable',
      () async {
        const config = BenchmarkConfig(
          baseUrl: 'http://127.0.0.1:8080',
          scenario: BenchmarkScenario.bytes,
          concurrency: 2,
          totalRequests: 3,
          payloadSize: 2048,
          warmupRequests: 2,
          timeoutMillis: 3000,
        );

        final transport = _RecordingBenchmarkTransport();
        final metrics = await const BenchmarkRunner().run(
          config: config,
          transport: transport,
        );

        expect(metrics.totalRequests, 3);
        expect(metrics.successCount, 3);
        expect(metrics.firstRequestLatency, isNot(Duration.zero));
        expect(metrics.postWarmupAverageLatency, isNot(Duration.zero));
        expect(
          transport.requestedSeeds,
          <String>['0', '1', '2', '3', '4', '5'],
        );
      },
    );

    test(
      'continues when the first request fails and still measures the main run',
      () async {
        const config = BenchmarkConfig(
          baseUrl: 'http://127.0.0.1:8080',
          scenario: BenchmarkScenario.bytes,
          concurrency: 2,
          totalRequests: 3,
          payloadSize: 2048,
          warmupRequests: 2,
          timeoutMillis: 3000,
        );

        final transport = _RecordingBenchmarkTransport(
          failCallIndices: <int>{0},
        );
        final metrics = await const BenchmarkRunner().run(
          config: config,
          transport: transport,
        );

        expect(metrics.totalRequests, 3);
        expect(metrics.successCount, 3);
        expect(metrics.failureCount, 0);
        expect(metrics.firstRequestLatency, isNot(Duration.zero));
        expect(
          transport.requestedSeeds,
          <String>['0', '1', '2', '3', '4', '5'],
        );
      },
    );
  });

  group('BenchmarkMetrics', () {
    test('aggregates richer latency and failure summary', () {
      final metrics = BenchmarkMetrics.fromSamples(
        transportLabel: 'nexa_http',
        totalDuration: const Duration(milliseconds: 400),
        firstRequestLatency: const Duration(milliseconds: 40),
        runOrderIndex: 1,
        samples: const <BenchmarkSample>[
          BenchmarkSample(
            latency: Duration(milliseconds: 80),
            bytesReceived: 1024,
            isSuccess: true,
          ),
          BenchmarkSample(
            latency: Duration(milliseconds: 120),
            bytesReceived: 0,
            isSuccess: false,
            statusCode: 404,
          ),
          BenchmarkSample(
            latency: Duration(milliseconds: 250),
            bytesReceived: 0,
            isSuccess: false,
            errorMessage: 'TimeoutException: request timed out',
          ),
          BenchmarkSample(
            latency: Duration(milliseconds: 300),
            bytesReceived: 0,
            isSuccess: false,
            errorMessage: 'SocketException: broken pipe',
          ),
        ],
      );

      expect(metrics.firstRequestLatency, const Duration(milliseconds: 40));
      expect(metrics.runOrderIndex, 1);
      expect(metrics.successCount, 1);
      expect(metrics.failureCount, 3);
      expect(metrics.totalBytes, 1024);
      expect(metrics.averageLatency, const Duration(milliseconds: 188));
      expect(
        metrics.postWarmupAverageLatency,
        const Duration(milliseconds: 188),
      );
      expect(metrics.p50Latency, const Duration(milliseconds: 120));
      expect(metrics.p95Latency, const Duration(milliseconds: 300));
      expect(metrics.p99Latency, const Duration(milliseconds: 300));
      expect(metrics.maxLatency, const Duration(milliseconds: 300));
      expect(
        metrics.failureBreakdown,
        const <String, int>{
          'http_error': 1,
          'timeout': 1,
          'transport_error': 1,
        },
      );
      expect(metrics.requestsPerSecond, closeTo(10.0, 0.0001));
      expect(metrics.megabytesPerSecond, closeTo(0.00244140625, 0.0000001));
    });

    test('exports richer benchmark payload fields', () {
      const config = BenchmarkConfig(
        baseUrl: 'http://127.0.0.1:8080',
        scenario: BenchmarkScenario.bytes,
        concurrency: 4,
        totalRequests: 12,
        payloadSize: 2048,
        warmupRequests: 2,
        timeoutMillis: 3000,
      );

      final dartMetrics = BenchmarkMetrics.fromSamples(
        transportLabel: 'Dart HttpClient',
        totalDuration: const Duration(milliseconds: 250),
        firstRequestLatency: const Duration(milliseconds: 50),
        runOrderIndex: 0,
        samples: const <BenchmarkSample>[
          BenchmarkSample(
            latency: Duration(milliseconds: 10),
            bytesReceived: 512,
            isSuccess: true,
          ),
        ],
      );
      final nexaMetrics = BenchmarkMetrics.fromSamples(
        transportLabel: 'nexa_http',
        totalDuration: const Duration(milliseconds: 200),
        firstRequestLatency: const Duration(milliseconds: 25),
        runOrderIndex: 1,
        samples: const <BenchmarkSample>[
          BenchmarkSample(
            latency: Duration(milliseconds: 8),
            bytesReceived: 512,
            isSuccess: true,
          ),
        ],
      );

      final payload = buildBenchmarkSuccessPayload(
        config: config,
        dartMetrics: dartMetrics,
        nexaMetrics: nexaMetrics,
      );

      final results = payload['results']! as List<Map<String, Object?>>;
      expect(results[0]['firstRequestLatencyMillis'], 50);
      expect(results[0]['postWarmupAverageLatencyMillis'], 10);
      expect(results[0]['p99LatencyMillis'], 10);
      expect(results[0]['maxLatencyMillis'], 10);
      expect(results[0]['runOrderIndex'], 0);
      expect(results[1]['runOrderIndex'], 1);
    });
  });
}

final class _RecordingBenchmarkTransport implements BenchmarkTransport {
  _RecordingBenchmarkTransport({this.failCallIndices = const <int>{}});

  final Set<int> failCallIndices;
  final List<Uri> _uris = <Uri>[];
  int _callCount = 0;

  List<String> get requestedSeeds => _uris
      .map((uri) => uri.queryParameters['seed'] ?? '')
      .toList(growable: false);

  @override
  String get label => 'recording';

  @override
  Future<void> close() async {}

  @override
  Future<BenchmarkFetchResult> fetch({
    required Uri uri,
    required Duration timeout,
  }) async {
    final callIndex = _callCount;
    _callCount += 1;
    _uris.add(uri);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (failCallIndices.contains(callIndex)) {
      throw TimeoutException('simulated timeout');
    }
    return const BenchmarkFetchResult(statusCode: 200, bytesReceived: 256);
  }
}
