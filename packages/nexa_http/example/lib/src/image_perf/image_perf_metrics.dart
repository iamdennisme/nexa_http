import 'image_request_scheduler.dart';

class ImageRequestSample {
  const ImageRequestSample({
    required this.url,
    required this.elapsed,
    required this.bytes,
    required this.succeeded,
    this.priority,
    this.statusCode,
    this.error,
  });

  final String url;
  final Duration elapsed;
  final int bytes;
  final bool succeeded;
  final ImageRequestPriority? priority;
  final int? statusCode;
  final String? error;
}

class FramePerfSample {
  const FramePerfSample({
    required this.totalSpan,
    required this.buildDuration,
    required this.rasterDuration,
  });

  final Duration totalSpan;
  final Duration buildDuration;
  final Duration rasterDuration;
}

class ImagePerfMetrics {
  const ImagePerfMetrics({
    required this.firstScreenElapsed,
    required this.requestCount,
    required this.successCount,
    required this.failureCount,
    required this.totalBytes,
    required this.highPriorityRequestCount,
    required this.mediumPriorityRequestCount,
    required this.lowPriorityRequestCount,
    required this.averageLatency,
    required this.p95Latency,
    required this.slowFrameCount,
    required this.maxRasterDuration,
    required this.throughputMiBPerSecond,
  });

  factory ImagePerfMetrics.fromSamples({
    required Duration? firstScreenElapsed,
    required List<ImageRequestSample> samples,
    required List<FramePerfSample> frameSamples,
  }) {
    if (samples.isEmpty) {
      return ImagePerfMetrics(
        firstScreenElapsed: firstScreenElapsed,
        requestCount: 0,
        successCount: 0,
        failureCount: 0,
        totalBytes: 0,
        highPriorityRequestCount: 0,
        mediumPriorityRequestCount: 0,
        lowPriorityRequestCount: 0,
        averageLatency: Duration.zero,
        p95Latency: Duration.zero,
        slowFrameCount: 0,
        maxRasterDuration: Duration.zero,
        throughputMiBPerSecond: 0,
      );
    }

    final successCount = samples.where((sample) => sample.succeeded).length;
    final failureCount = samples.length - successCount;
    final totalBytes = samples.fold<int>(
      0,
      (sum, sample) => sum + sample.bytes,
    );
    final highPriorityRequestCount = samples
        .where((sample) => sample.priority == ImageRequestPriority.high)
        .length;
    final mediumPriorityRequestCount = samples
        .where((sample) => sample.priority == ImageRequestPriority.medium)
        .length;
    final lowPriorityRequestCount = samples
        .where((sample) => sample.priority == ImageRequestPriority.low)
        .length;
    final elapsedMicros = samples.fold<int>(
      0,
      (sum, sample) => sum + sample.elapsed.inMicroseconds,
    );
    final averageLatency = Duration(
      microseconds: elapsedMicros ~/ samples.length,
    );

    final sortedLatencies =
        samples.map((sample) => sample.elapsed).toList(growable: false)..sort();
    final p95Index = ((sortedLatencies.length * 0.95).ceil() - 1)
        .clamp(0, sortedLatencies.length - 1);
    final p95Latency = sortedLatencies[p95Index];

    final slowFrameCount = frameSamples
        .where(
          (sample) => sample.totalSpan > const Duration(milliseconds: 16),
        )
        .length;
    final maxRasterMicros = frameSamples.fold<int>(
      0,
      (maxMicros, sample) => sample.rasterDuration.inMicroseconds > maxMicros
          ? sample.rasterDuration.inMicroseconds
          : maxMicros,
    );
    final maxElapsedMicros = samples.fold<int>(
      0,
      (maxMicros, sample) => sample.elapsed.inMicroseconds > maxMicros
          ? sample.elapsed.inMicroseconds
          : maxMicros,
    );
    final throughputMiBPerSecond = maxElapsedMicros == 0
        ? 0
        : (totalBytes / (1024 * 1024)) /
            (maxElapsedMicros / Duration.microsecondsPerSecond);

    return ImagePerfMetrics(
      firstScreenElapsed: firstScreenElapsed,
      requestCount: samples.length,
      successCount: successCount,
      failureCount: failureCount,
      totalBytes: totalBytes,
      highPriorityRequestCount: highPriorityRequestCount,
      mediumPriorityRequestCount: mediumPriorityRequestCount,
      lowPriorityRequestCount: lowPriorityRequestCount,
      averageLatency: averageLatency,
      p95Latency: p95Latency,
      slowFrameCount: slowFrameCount,
      maxRasterDuration: Duration(microseconds: maxRasterMicros),
      throughputMiBPerSecond: throughputMiBPerSecond.toDouble(),
    );
  }

  final Duration? firstScreenElapsed;
  final int requestCount;
  final int successCount;
  final int failureCount;
  final int totalBytes;
  final int highPriorityRequestCount;
  final int mediumPriorityRequestCount;
  final int lowPriorityRequestCount;
  final Duration averageLatency;
  final Duration p95Latency;
  final int slowFrameCount;
  final Duration maxRasterDuration;
  final double throughputMiBPerSecond;
}
