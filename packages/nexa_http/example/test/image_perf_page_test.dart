import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/src/image_perf/image_cache_transport_registry.dart';
import 'package:nexa_http_example/src/image_perf/image_request_scheduler.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_metrics.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_page.dart';

void main() {
  test('autorun image scenario expands preview grid to full content', () {
    expect(
      resolveImagePerfPreviewMode(ImagePerfScenario.image),
      ImagePerfPreviewMode.fullContent,
    );
  });

  test('autoscroll scenario keeps viewport-backed preview grid', () {
    expect(
      resolveImagePerfPreviewMode(ImagePerfScenario.autoScroll),
      ImagePerfPreviewMode.viewport,
    );
  });

  test('manual mode keeps viewport-backed preview grid', () {
    expect(
      resolveImagePerfPreviewMode(null),
      ImagePerfPreviewMode.viewport,
    );
  });

  test('prioritizes first-screen tiles as high priority', () {
    expect(
      resolveImageRequestPriorityForTile(0),
      ImageRequestPriority.high,
    );
    expect(
      resolveImageRequestPriorityForTile(imagePerfFirstScreenTileCount - 1),
      ImageRequestPriority.high,
    );
  });

  test('prioritizes near-viewport tiles as medium priority', () {
    expect(
      resolveImageRequestPriorityForTile(imagePerfFirstScreenTileCount),
      ImageRequestPriority.medium,
    );
    expect(
      resolveImageRequestPriorityForTile(imagePerfNearViewportTileCount - 1),
      ImageRequestPriority.medium,
    );
  });

  test('prioritizes background tiles as low priority', () {
    expect(
      resolveImageRequestPriorityForTile(imagePerfNearViewportTileCount),
      ImageRequestPriority.low,
    );
  });

  test('builds the metrics card placeholder when no samples have completed',
      () {
    final metrics = ImagePerfMetrics.fromSamples(
      firstScreenElapsed: null,
      samples: const <ImageRequestSample>[],
      frameSamples: const <FramePerfSample>[],
    );

    expect(
      buildImagePerfMetricsCardContent(
        transportMode: ImageTransportMode.rustNet,
        metrics: metrics,
      ),
      'No samples collected yet.',
    );
  });

  test('builds the metrics card content from completed request samples', () {
    final metrics = ImagePerfMetrics.fromSamples(
      firstScreenElapsed: const Duration(milliseconds: 420),
      samples: const <ImageRequestSample>[
        ImageRequestSample(
          url: 'https://example.com/a.png',
          elapsed: Duration(milliseconds: 120),
          bytes: 4096,
          succeeded: true,
          priority: ImageRequestPriority.high,
          dispatchSequence: 1,
        ),
        ImageRequestSample(
          url: 'https://example.com/b.png',
          elapsed: Duration(milliseconds: 250),
          bytes: 0,
          succeeded: false,
          priority: ImageRequestPriority.low,
          dispatchSequence: 2,
          error: 'HTTP 500',
        ),
      ],
      frameSamples: const <FramePerfSample>[],
    );

    expect(
      buildImagePerfMetricsCardContent(
        transportMode: ImageTransportMode.rustNet,
        metrics: metrics,
      ),
      allOf(
        contains('transport: rustNet'),
        contains('requests: 2'),
        contains('failure: 1'),
        contains('priority_counts: high=1 medium=0 low=1'),
        contains('bytes: 4096'),
      ),
    );
  });

  test('builds preview grid content for idle and active states', () {
    expect(
      buildImagePerfPreviewGridContent(
        isSessionActive: false,
        runId: 0,
        imageCount: 24,
        baseUrl: 'http://127.0.0.1:8080',
      ),
      'Press "Run image test" to load fixture images.',
    );
    expect(
      buildImagePerfPreviewGridContent(
        isSessionActive: true,
        runId: 3,
        imageCount: 24,
        baseUrl: 'http://127.0.0.1:8080',
      ),
      'Run #3 loading 24 fixture images from http://127.0.0.1:8080',
    );
  });
}
