import 'package:flutter_test/flutter_test.dart';
import 'package:rust_net/rust_net.dart';
import 'package:rust_net_example/src/image_perf/image_perf_metrics.dart';
import 'package:rust_net_example/src/image_perf/rust_net_image_file_service.dart';

void main() {
  test('forwards request headers, maps response, and records a sample',
      () async {
    late RustNetRequest capturedRequest;
    ImageRequestSample? capturedSample;
    final service = RustNetImageFileService(
      executor: _FakeHttpExecutor((request) async {
        capturedRequest = request;
        return const RustNetResponse(
          statusCode: 200,
          headers: <String, List<String>>{
            'Cache-Control': <String>['max-age=60'],
            'ETag': <String>['"image-etag"'],
            'Content-Type': <String>['image/png'],
          },
          bodyBytes: <int>[1, 2, 3, 4],
        );
      }),
      onSample: (sample) {
        capturedSample = sample;
      },
    );

    final response = await service.get(
      'https://example.com/poster.png',
      headers: const <String, String>{'accept': 'image/*'},
    );

    expect(
      capturedRequest.uri,
      Uri.parse('https://example.com/poster.png'),
    );
    expect(capturedRequest.headers['accept'], 'image/*');
    expect(response.statusCode, 200);
    expect(
      await response.content.expand((chunk) => chunk).toList(),
      <int>[1, 2, 3, 4],
    );
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
    expect(capturedSample!.statusCode, 200);
  });
}

final class _FakeHttpExecutor implements HttpExecutor {
  _FakeHttpExecutor(this._handler);

  final Future<RustNetResponse> Function(RustNetRequest request) _handler;

  @override
  Future<void> close() async {}

  @override
  Future<RustNetResponse> execute(RustNetRequest request) {
    return _handler(request);
  }
}
