enum BenchmarkScenario {
  bytes,
  image,
}

final class BenchmarkConfig {
  const BenchmarkConfig({
    required this.baseUrl,
    required this.scenario,
    required this.concurrency,
    required this.totalRequests,
    required this.payloadSize,
    required this.warmupRequests,
    required this.timeoutMillis,
  });

  final String baseUrl;
  final BenchmarkScenario scenario;
  final int concurrency;
  final int totalRequests;
  final int payloadSize;
  final int warmupRequests;
  final int timeoutMillis;

  Duration get timeout => Duration(milliseconds: timeoutMillis);
}

final class BenchmarkSample {
  const BenchmarkSample({
    required this.latency,
    required this.bytesReceived,
    required this.isSuccess,
    this.statusCode,
    this.errorMessage,
  });

  final Duration latency;
  final int bytesReceived;
  final bool isSuccess;
  final int? statusCode;
  final String? errorMessage;
}

final class BenchmarkMetrics {
  const BenchmarkMetrics({
    required this.transportLabel,
    required this.totalDuration,
    required this.successCount,
    required this.failureCount,
    required this.totalBytes,
    required this.averageLatency,
    required this.p50Latency,
    required this.p95Latency,
    required this.requestsPerSecond,
    required this.megabytesPerSecond,
    required this.samples,
  });

  final String transportLabel;
  final Duration totalDuration;
  final int successCount;
  final int failureCount;
  final int totalBytes;
  final Duration averageLatency;
  final Duration p50Latency;
  final Duration p95Latency;
  final double requestsPerSecond;
  final double megabytesPerSecond;
  final List<BenchmarkSample> samples;

  int get totalRequests => samples.length;

  static BenchmarkMetrics fromSamples({
    required String transportLabel,
    required Duration totalDuration,
    required List<BenchmarkSample> samples,
  }) {
    final completedSamples = List<BenchmarkSample>.unmodifiable(samples);
    final sortedLatencies = completedSamples
        .map((sample) => sample.latency.inMicroseconds)
        .toList()
      ..sort();
    final totalLatencyMicros = completedSamples.fold<int>(
      0,
      (sum, sample) => sum + sample.latency.inMicroseconds,
    );
    final successCount =
        completedSamples.where((sample) => sample.isSuccess).length;
    final failureCount = completedSamples.length - successCount;
    final totalBytes = completedSamples.fold<int>(
      0,
      (sum, sample) => sum + sample.bytesReceived,
    );
    final requestsPerSecond = totalDuration.inMicroseconds == 0
        ? 0.0
        : completedSamples.length * 1000000 / totalDuration.inMicroseconds;
    final megabytesPerSecond = totalDuration.inMicroseconds == 0
        ? 0.0
        : totalBytes / 1048576 / (totalDuration.inMicroseconds / 1000000);

    return BenchmarkMetrics(
      transportLabel: transportLabel,
      totalDuration: totalDuration,
      successCount: successCount,
      failureCount: failureCount,
      totalBytes: totalBytes,
      averageLatency: _durationFromMillis(
        completedSamples.isEmpty
            ? 0
            : ((totalLatencyMicros / completedSamples.length) / 1000).round(),
      ),
      p50Latency: _percentile(sortedLatencies, 0.50),
      p95Latency: _percentile(sortedLatencies, 0.95),
      requestsPerSecond: requestsPerSecond,
      megabytesPerSecond: megabytesPerSecond,
      samples: completedSamples,
    );
  }

  static Duration _percentile(List<int> sortedMicros, double percentile) {
    if (sortedMicros.isEmpty) {
      return Duration.zero;
    }
    final rank =
        (percentile * sortedMicros.length).ceil().clamp(1, sortedMicros.length);
    return _durationFromMicros(sortedMicros[rank - 1]);
  }

  static Duration _durationFromMicros(int value) {
    return Duration(microseconds: value);
  }

  static Duration _durationFromMillis(int value) {
    return Duration(milliseconds: value);
  }
}
