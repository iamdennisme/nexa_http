import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/src/image_perf/image_request_scheduler.dart';
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
}
