enum BenchmarkScenario {
  bytes,
  image,
}

final class BenchmarkExecutionResult {
  const BenchmarkExecutionResult({
    required this.dartMetrics,
    required this.nexaMetrics,
  });

  final BenchmarkMetrics dartMetrics;
  final BenchmarkMetrics nexaMetrics;
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
    required this.firstRequestLatency,
    required this.successCount,
    required this.failureCount,
    required this.totalBytes,
    required this.postWarmupAverageLatency,
    required this.p50Latency,
    required this.p95Latency,
    required this.p99Latency,
    required this.maxLatency,
    required this.requestsPerSecond,
    required this.megabytesPerSecond,
    required this.failureBreakdown,
    required this.samples,
    this.runOrderIndex,
  });

  final String transportLabel;
  final Duration totalDuration;
  final Duration firstRequestLatency;
  final int successCount;
  final int failureCount;
  final int totalBytes;
  final Duration postWarmupAverageLatency;
  final Duration p50Latency;
  final Duration p95Latency;
  final Duration p99Latency;
  final Duration maxLatency;
  final double requestsPerSecond;
  final double megabytesPerSecond;
  final Map<String, int> failureBreakdown;
  final List<BenchmarkSample> samples;
  final int? runOrderIndex;

  int get totalRequests => samples.length;
  Duration get averageLatency => postWarmupAverageLatency;

  BenchmarkMetrics withRunOrderIndex(int value) {
    return BenchmarkMetrics(
      transportLabel: transportLabel,
      totalDuration: totalDuration,
      firstRequestLatency: firstRequestLatency,
      successCount: successCount,
      failureCount: failureCount,
      totalBytes: totalBytes,
      postWarmupAverageLatency: postWarmupAverageLatency,
      p50Latency: p50Latency,
      p95Latency: p95Latency,
      p99Latency: p99Latency,
      maxLatency: maxLatency,
      requestsPerSecond: requestsPerSecond,
      megabytesPerSecond: megabytesPerSecond,
      failureBreakdown: failureBreakdown,
      samples: samples,
      runOrderIndex: value,
    );
  }

  static BenchmarkMetrics fromSamples({
    required String transportLabel,
    required Duration totalDuration,
    required Duration firstRequestLatency,
    required List<BenchmarkSample> samples,
    int? runOrderIndex,
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
    final failureBreakdown = <String, int>{};
    for (final sample in completedSamples.where((sample) => !sample.isSuccess)) {
      final key = _failureCategoryForSample(sample);
      failureBreakdown.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final requestsPerSecond = totalDuration.inMicroseconds == 0
        ? 0.0
        : completedSamples.length * 1000000 / totalDuration.inMicroseconds;
    final megabytesPerSecond = totalDuration.inMicroseconds == 0
        ? 0.0
        : totalBytes / 1048576 / (totalDuration.inMicroseconds / 1000000);

    return BenchmarkMetrics(
      transportLabel: transportLabel,
      totalDuration: totalDuration,
      firstRequestLatency: firstRequestLatency,
      successCount: successCount,
      failureCount: failureCount,
      totalBytes: totalBytes,
      postWarmupAverageLatency: _durationFromMillis(
        completedSamples.isEmpty
            ? 0
            : ((totalLatencyMicros / completedSamples.length) / 1000).round(),
      ),
      p50Latency: _percentile(sortedLatencies, 0.50),
      p95Latency: _percentile(sortedLatencies, 0.95),
      p99Latency: _percentile(sortedLatencies, 0.99),
      maxLatency: _durationFromMicros(
        sortedLatencies.isEmpty ? 0 : sortedLatencies.last,
      ),
      requestsPerSecond: requestsPerSecond,
      megabytesPerSecond: megabytesPerSecond,
      failureBreakdown: Map<String, int>.unmodifiable(failureBreakdown),
      samples: completedSamples,
      runOrderIndex: runOrderIndex,
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

  static String _failureCategoryForSample(BenchmarkSample sample) {
    final statusCode = sample.statusCode;
    if (statusCode != null && statusCode >= 400) {
      return 'http_error';
    }

    final message = sample.errorMessage?.toLowerCase() ?? '';
    if (message.contains('timeoutexception') || message.contains('timed out')) {
      return 'timeout';
    }

    return 'transport_error';
  }
}
