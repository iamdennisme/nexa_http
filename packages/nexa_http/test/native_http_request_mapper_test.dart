import 'package:nexa_http/src/data/mappers/native_http_request_mapper.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('keeps request body as raw bytes and excludes it from request json', () {
    final dto = NativeHttpRequestMapper.toDto(
      clientConfig: const NexaHttpClientConfig(),
      request: NexaHttpRequest(
        method: NexaHttpMethod.post,
        uri: Uri.parse('https://example.com/upload'),
        bodyBytes: <int>[1, 2, 3, 4],
      ),
    );

    expect(dto.bodyBytes, const <int>[1, 2, 3, 4]);
    expect(dto.toJson().containsKey('body_base64'), isFalse);
  });
}
