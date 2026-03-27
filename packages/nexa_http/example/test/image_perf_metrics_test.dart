import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_metrics.dart';

void main() {
  test('aggregates request latency, throughput, and failures', () {
    final report = ImagePerfMetrics.fromSamples(
      firstScreenElapsed: const Duration(milliseconds: 420),
      samples: const <ImageRequestSample>[
        ImageRequestSample(
          url: 'https://example.com/a.png',
          elapsed: Duration(milliseconds: 100),
          bytes: 100 * 1024,
          succeeded: true,
        ),
        ImageRequestSample(
          url: 'https://example.com/b.png',
          elapsed: Duration(milliseconds: 250),
          bytes: 150 * 1024,
          succeeded: true,
        ),
        ImageRequestSample(
          url: 'https://example.com/c.png',
          elapsed: Duration(milliseconds: 400),
          bytes: 0,
          succeeded: false,
          statusCode: 500,
          error: 'boom',
        ),
      ],
      frameSamples: const <FramePerfSample>[
        FramePerfSample(
          totalSpan: Duration(milliseconds: 18),
          buildDuration: Duration(milliseconds: 7),
          rasterDuration: Duration(milliseconds: 10),
        ),
        FramePerfSample(
          totalSpan: Duration(milliseconds: 34),
          buildDuration: Duration(milliseconds: 12),
          rasterDuration: Duration(milliseconds: 20),
        ),
      ],
    );

    expect(report.requestCount, 3);
    expect(report.successCount, 2);
    expect(report.failureCount, 1);
    expect(report.totalBytes, 250 * 1024);
    expect(report.averageLatency, const Duration(milliseconds: 250));
    expect(report.p95Latency, const Duration(milliseconds: 400));
    expect(report.firstScreenElapsed, const Duration(milliseconds: 420));
    expect(report.slowFrameCount, 2);
    expect(report.maxRasterDuration, const Duration(milliseconds: 20));
    expect(report.throughputMiBPerSecond, closeTo(0.61, 0.01));
  });

  test('returns zero-like metrics for an empty sample set', () {
    final report = ImagePerfMetrics.fromSamples(
      firstScreenElapsed: null,
      samples: const <ImageRequestSample>[],
      frameSamples: const <FramePerfSample>[],
    );

    expect(report.requestCount, 0);
    expect(report.successCount, 0);
    expect(report.failureCount, 0);
    expect(report.totalBytes, 0);
    expect(report.averageLatency, Duration.zero);
    expect(report.p95Latency, Duration.zero);
    expect(report.firstScreenElapsed, isNull);
    expect(report.slowFrameCount, 0);
    expect(report.maxRasterDuration, Duration.zero);
    expect(report.throughputMiBPerSecond, 0);
  });
}
