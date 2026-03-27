import 'package:flutter_test/flutter_test.dart';
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
          ),
          ImageRequestSample(
            url: 'http://192.168.1.16:8080/image?id=poster-1',
            elapsed: Duration(milliseconds: 5),
            bytes: 0,
            succeeded: false,
            error: 'SocketException: Connection refused',
          ),
          ImageRequestSample(
            url: 'http://192.168.1.16:8080/image?id=poster-2',
            elapsed: Duration(milliseconds: 8),
            bytes: 0,
            succeeded: false,
            error: 'HandshakeException: bad certificate',
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
        ),
        ImageRequestSample(
          url: 'http://192.168.1.16:8080/image?id=poster-1',
          elapsed: Duration(milliseconds: 5),
          bytes: 0,
          succeeded: false,
          error: 'SocketException: Connection refused',
        ),
        ImageRequestSample(
          url: 'http://192.168.1.16:8080/image?id=poster-2',
          elapsed: Duration(milliseconds: 8),
          bytes: 0,
          succeeded: false,
          error: 'HandshakeException: bad certificate',
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
  });
}
