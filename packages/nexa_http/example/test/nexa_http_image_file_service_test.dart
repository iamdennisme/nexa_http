import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_metrics.dart';
import 'package:nexa_http_example/src/image_perf/nexa_http_image_file_service.dart';

void main() {
  test(
    'returns a streaming content response and records a sample after content completes',
    () async {
      late NexaHttpRequest capturedRequest;
      ImageRequestSample? capturedSample;
      final bodyController = StreamController<Uint8List>();
      addTearDown(() async {
        if (!bodyController.isClosed) {
          await bodyController.close();
        }
      });
      final service = NexaHttpImageFileService(
        executor: _FakeHttpExecutor((request) async {
          capturedRequest = request;
          return NexaHttpStreamedResponse(
            statusCode: 200,
            headers: <String, List<String>>{
              'Cache-Control': <String>['max-age=60'],
              'ETag': <String>['"image-etag"'],
              'Content-Type': <String>['image/png'],
            },
            contentLength: 4,
            bodyStream: bodyController.stream,
          );
        }),
        onSample: (sample) {
          capturedSample = sample;
        },
      );

      final responseFuture = service.get(
        'https://example.com/poster.png',
        headers: const <String, String>{'accept': 'image/*'},
      );
      bodyController.add(Uint8List.fromList(const <int>[1, 2]));
      final response = await responseFuture.timeout(
        const Duration(milliseconds: 100),
      );

      expect(capturedRequest.uri, Uri.parse('https://example.com/poster.png'));
      expect(capturedRequest.headers['accept'], 'image/*');
      expect(response.statusCode, 200);
      expect(capturedSample, isNull);

      bodyController.add(Uint8List.fromList(const <int>[3, 4]));
      final closeFuture = bodyController.close();
      expect(await response.content.expand((chunk) => chunk).toList(), <int>[
        1,
        2,
        3,
        4,
      ]);
      await closeFuture;
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
    },
  );
}

final class _FakeHttpExecutor implements HttpExecutor {
  _FakeHttpExecutor(this._handler);

  final Future<NexaHttpStreamedResponse> Function(NexaHttpRequest request)
      _handler;

  @override
  Future<void> close() async {}

  @override
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request) {
    return _handler(request);
  }
}
