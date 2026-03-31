import 'package:flutter_test/flutter_test.dart';
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
  });

  group('BenchmarkMetrics', () {
    test('aggregates latency and throughput summary', () {
      final metrics = BenchmarkMetrics.fromSamples(
        transportLabel: 'nexa_http',
        totalDuration: const Duration(milliseconds: 400),
        samples: const <BenchmarkSample>[
          BenchmarkSample(
            latency: Duration(milliseconds: 80),
            bytesReceived: 1024,
            isSuccess: true,
          ),
          BenchmarkSample(
            latency: Duration(milliseconds: 120),
            bytesReceived: 2048,
            isSuccess: true,
          ),
          BenchmarkSample(
            latency: Duration(milliseconds: 300),
            bytesReceived: 0,
            isSuccess: false,
          ),
        ],
      );

      expect(metrics.successCount, 2);
      expect(metrics.failureCount, 1);
      expect(metrics.totalBytes, 3072);
      expect(metrics.averageLatency, const Duration(milliseconds: 167));
      expect(metrics.p50Latency, const Duration(milliseconds: 120));
      expect(metrics.p95Latency, const Duration(milliseconds: 300));
      expect(metrics.requestsPerSecond, closeTo(7.5, 0.0001));
      expect(metrics.megabytesPerSecond, closeTo(0.00732421875, 0.0000001));
    });
  });
}
