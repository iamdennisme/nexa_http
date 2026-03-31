import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/engine/nexa_http_engine_manager.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_protocol.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_proxy.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_metrics.dart';
import 'package:nexa_http_example/src/image_perf/nexa_http_image_file_service.dart';

void main() {
  tearDown(() {
    NexaHttpEngineManager.resetForTesting();
  });

  test(
    'forwards request headers, maps response, and records a sample',
    () async {
      final proxy = _FakeWorkerProxy(
        responses: <NexaHttpWorkerResponse>[
          const NexaHttpWorkerSuccessResponse(
            requestId: 1,
            result: <String, Object?>{'leaseId': 7},
          ),
          const NexaHttpWorkerSuccessResponse(
            requestId: 2,
            result: <String, Object?>{
              'statusCode': 200,
              'headers': <String, Object?>{
                'Cache-Control': <Object?>['max-age=60'],
                'ETag': <Object?>['"image-etag"'],
                'Content-Type': <Object?>['image/png'],
              },
              'bodyBytes': <Object?>[1, 2, 3, 4],
            },
          ),
        ],
      );
      NexaHttpEngineManager.installForTesting(
        NexaHttpEngineManager(workerProxy: proxy),
      );
      ImageRequestSample? capturedSample;
      final client = NexaHttpClient();
      final service = NexaHttpImageFileService(
        client: client,
        onSample: (sample) {
          capturedSample = sample;
        },
      );

      final response = await service.get(
        'https://example.com/poster.png',
        headers: const <String, String>{'accept': 'image/*'},
      );

      expect(response.statusCode, 200);
      expect(await response.content.expand((chunk) => chunk).toList(), <int>[
        1,
        2,
        3,
        4,
      ]);
      expect(response.contentLength, 4);
      expect(response.eTag, '"image-etag"');
      expect(response.fileExtension, 'png');
      expect(
        response.validTill.isAfter(
          DateTime.now().add(const Duration(seconds: 50)),
        ),
        isTrue,
      );
      expect(capturedSample, isNotNull);
      expect(capturedSample!.url, 'https://example.com/poster.png');
      expect(capturedSample!.bytes, 4);
      expect(capturedSample!.succeeded, isTrue);
      expect(capturedSample!.dispatchSequence, 0);
      expect(capturedSample!.statusCode, 200);

      expect(proxy.requests[1], isA<NexaHttpExecuteWorkerRequest>());
      final executeRequest = proxy.requests[1] as NexaHttpExecuteWorkerRequest;
      expect(
        executeRequest.request['url'],
        'https://example.com/poster.png',
      );
      expect(
        executeRequest.request['headers'],
        <String, String>{'accept': 'image/*'},
      );
    },
  );

  test('close is a no-op for an externally supplied client', () async {
    final proxy = _FakeWorkerProxy(
      responses: <NexaHttpWorkerResponse>[
        const NexaHttpWorkerSuccessResponse(
          requestId: 1,
          result: <String, Object?>{'leaseId': 13},
        ),
      ],
    );
    NexaHttpEngineManager.installForTesting(
      NexaHttpEngineManager(workerProxy: proxy),
    );
    final service = NexaHttpImageFileService(client: NexaHttpClient());

    await service.close();

    expect(proxy.requests, isEmpty);
  });

  test('creates a default lightweight client when one is not supplied', () async {
    final proxy = _FakeWorkerProxy(
      responses: <NexaHttpWorkerResponse>[
        const NexaHttpWorkerSuccessResponse(
          requestId: 1,
          result: <String, Object?>{'leaseId': 17},
        ),
        const NexaHttpWorkerSuccessResponse(
          requestId: 2,
          result: <String, Object?>{
            'statusCode': 204,
            'headers': <String, Object?>{},
            'bodyBytes': <Object?>[],
          },
        ),
      ],
    );
    NexaHttpEngineManager.installForTesting(
      NexaHttpEngineManager(workerProxy: proxy),
    );
    final service = NexaHttpImageFileService();
    final response = await service.get('https://example.com/late.png');

    expect(response.statusCode, 204);
    expect(proxy.requests[1], isA<NexaHttpExecuteWorkerRequest>());
  });
}

final class _FakeWorkerProxy implements NexaHttpWorkerProxyClient {
  _FakeWorkerProxy({required List<NexaHttpWorkerResponse> responses})
    : _responses = responses;

  final List<NexaHttpWorkerResponse> _responses;
  final List<NexaHttpWorkerRequest> requests = <NexaHttpWorkerRequest>[];

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<NexaHttpWorkerResponse> send(NexaHttpWorkerRequest request) async {
    requests.add(request);
    return _responses[requests.length - 1];
  }
}
