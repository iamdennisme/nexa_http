import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http_example/src/image_perf/image_perf_metrics.dart';
import 'package:nexa_http_example/src/image_perf/nexa_http_image_file_service.dart';

void main() {
  test(
    'forwards request headers, maps response, and records a sample',
    () async {
      late NexaHttpRequest capturedRequest;
      ImageRequestSample? capturedSample;
      final service = NexaHttpImageFileService(
        client: NexaHttpClient(
          dataSource: _FakeNexaHttpNativeDataSource((request) async {
            capturedRequest = request;
            return const NexaHttpResponse(
              statusCode: 200,
              headers: <String, List<String>>{
                'Cache-Control': <String>['max-age=60'],
                'ETag': <String>['"image-etag"'],
                'Content-Type': <String>['image/png'],
              },
              bodyBytes: <int>[1, 2, 3, 4],
            );
          }),
        ),
        onSample: (sample) {
          capturedSample = sample;
        },
      );

      final response = await service.get(
        'https://example.com/poster.png',
        headers: const <String, String>{'accept': 'image/*'},
      );

      expect(capturedRequest.uri, Uri.parse('https://example.com/poster.png'));
      expect(capturedRequest.headers['accept'], 'image/*');
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
    },
  );
}

final class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNexaHttpNativeDataSource(this._handler);

  final Future<NexaHttpResponse> Function(NexaHttpRequest request) _handler;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<NexaHttpResponse> execute(int clientId, NativeHttpRequestDto request) {
    return _handler(
      NexaHttpRequest(
        method: NexaHttpMethod.values.firstWhere(
          (value) => value.wireValue == request.method,
        ),
        uri: Uri.parse(request.url),
        headers: request.headers,
        bodyBytes: request.bodyBytes,
        timeout: request.timeoutMs == null
            ? null
            : Duration(milliseconds: request.timeoutMs!),
      ),
    );
  }
}
