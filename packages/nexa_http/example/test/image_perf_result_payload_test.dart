import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/src/image_perf/image_request_scheduler.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_metrics.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_result_payload.dart';

void main() {
  test('includes failed sample errors in the result payload', () {
    final payload = buildImagePerfResultPayload(
      scenarioName: 'image',
      transportName: 'defaultHttp',
      baseUrl: 'http://192.168.1.16:8080',
      imageCount: 24,
      metrics: ImagePerfMetrics.fromSamples(
        firstScreenElapsed: null,
        samples: const <ImageRequestSample>[
          ImageRequestSample(
            url: 'http://192.168.1.16:8080/image?id=poster-0',
            elapsed: Duration(milliseconds: 3),
            bytes: 0,
            succeeded: false,
            error: 'SocketException: Connection refused',
            priority: ImageRequestPriority.low,
            dispatchSequence: 2,
          ),
          ImageRequestSample(
            url: 'http://192.168.1.16:8080/image?id=poster-1',
            elapsed: Duration(milliseconds: 5),
            bytes: 0,
            succeeded: false,
            error: 'SocketException: Connection refused',
            priority: ImageRequestPriority.high,
            dispatchSequence: 0,
          ),
          ImageRequestSample(
            url: 'http://192.168.1.16:8080/image?id=poster-2',
            elapsed: Duration(milliseconds: 8),
            bytes: 0,
            succeeded: false,
            error: 'HandshakeException: bad certificate',
            priority: ImageRequestPriority.medium,
            dispatchSequence: 1,
          ),
        ],
        frameSamples: const <FramePerfSample>[],
      ),
      samples: const <ImageRequestSample>[
        ImageRequestSample(
          url: 'http://192.168.1.16:8080/image?id=poster-0',
          elapsed: Duration(milliseconds: 3),
          bytes: 0,
          succeeded: false,
          error: 'SocketException: Connection refused',
          priority: ImageRequestPriority.low,
          dispatchSequence: 2,
        ),
        ImageRequestSample(
          url: 'http://192.168.1.16:8080/image?id=poster-1',
          elapsed: Duration(milliseconds: 5),
          bytes: 0,
          succeeded: false,
          error: 'SocketException: Connection refused',
          priority: ImageRequestPriority.high,
          dispatchSequence: 0,
        ),
        ImageRequestSample(
          url: 'http://192.168.1.16:8080/image?id=poster-2',
          elapsed: Duration(milliseconds: 8),
          bytes: 0,
          succeeded: false,
          error: 'HandshakeException: bad certificate',
          priority: ImageRequestPriority.medium,
          dispatchSequence: 1,
        ),
      ],
      rssBeforeBytes: 1,
      rssAfterBytes: 2,
      rssPeakBytes: 3,
    );

    expect(payload['failure_count'], 3);
    expect(payload['sample_errors'], const <String>[
      'SocketException: Connection refused',
      'HandshakeException: bad certificate',
    ]);
    expect(payload['failed_urls'], 3);
    expect(payload['dispatch_order_head'], const <Map<String, Object?>>[
      <String, Object?>{
        'dispatch_index': 0,
        'priority': 'high',
        'url': 'http://192.168.1.16:8080/image?id=poster-1',
      },
      <String, Object?>{
        'dispatch_index': 1,
        'priority': 'medium',
        'url': 'http://192.168.1.16:8080/image?id=poster-2',
      },
      <String, Object?>{
        'dispatch_index': 2,
        'priority': 'low',
        'url': 'http://192.168.1.16:8080/image?id=poster-0',
      },
    ]);
    expect(payload['completion_order_head'], const <Map<String, Object?>>[
      <String, Object?>{
        'completion_index': 0,
        'priority': 'low',
        'url': 'http://192.168.1.16:8080/image?id=poster-0',
      },
      <String, Object?>{
        'completion_index': 1,
        'priority': 'high',
        'url': 'http://192.168.1.16:8080/image?id=poster-1',
      },
      <String, Object?>{
        'completion_index': 2,
        'priority': 'medium',
        'url': 'http://192.168.1.16:8080/image?id=poster-2',
      },
    ]);
  });
}
