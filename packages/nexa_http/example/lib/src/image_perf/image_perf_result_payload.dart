import 'image_perf_metrics.dart';

Map<String, Object?> buildImagePerfResultPayload({
  required String scenarioName,
  required String transportName,
  required String baseUrl,
  required int imageCount,
  required ImagePerfMetrics metrics,
  required List<ImageRequestSample> samples,
  required int? rssBeforeBytes,
  required int? rssAfterBytes,
  required int rssPeakBytes,
}) {
  final sampleErrors = <String>{
    for (final sample in samples)
      if (!sample.succeeded && sample.error != null) sample.error!,
  }.take(3).toList(growable: false);
  final dispatchOrderHead = <Map<String, Object?>>[
    for (final entry in metrics.dispatchOrderHead)
      <String, Object?>{
        'dispatch_index': entry.index,
        'priority': entry.priority.name,
        'url': entry.url,
      },
  ];
  final completionOrderHead = <Map<String, Object?>>[
    for (final entry in metrics.completionOrderHead)
      <String, Object?>{
        'completion_index': entry.index,
        'priority': entry.priority.name,
        'url': entry.url,
      },
  ];

  return <String, Object?>{
    'kind': 'image_perf_result',
    'scenario': scenarioName,
    'transport': transportName,
    'base_url': baseUrl,
    'image_count': imageCount,
    'first_screen_ms': metrics.firstScreenElapsed?.inMilliseconds,
    'request_count': metrics.requestCount,
    'success_count': metrics.successCount,
    'failure_count': metrics.failureCount,
    'average_latency_ms': metrics.averageLatency.inMilliseconds,
    'p95_latency_ms': metrics.p95Latency.inMilliseconds,
    'total_bytes': metrics.totalBytes,
    'throughput_mib_s': metrics.throughputMiBPerSecond,
    'slow_frames': metrics.slowFrameCount,
    'max_raster_ms': metrics.maxRasterDuration.inMilliseconds,
    'rss_before_bytes': rssBeforeBytes,
    'rss_after_bytes': rssAfterBytes,
    'rss_peak_bytes': rssPeakBytes,
    'failed_urls': metrics.failureCount,
    if (dispatchOrderHead.isNotEmpty) 'dispatch_order_head': dispatchOrderHead,
    if (completionOrderHead.isNotEmpty)
      'completion_order_head': completionOrderHead,
    if (sampleErrors.isNotEmpty) 'sample_errors': sampleErrors,
  };
}
