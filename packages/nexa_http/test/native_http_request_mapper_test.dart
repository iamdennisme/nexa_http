import 'package:nexa_http/src/data/mappers/native_http_request_mapper.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('encodes structured native request fields without request json', () {
    final dto = NativeHttpRequestMapper.toDto(
      clientConfig: const NexaHttpClientConfig(
        timeout: Duration(seconds: 2),
        defaultHeaders: <String, String>{'x-client': 'nexa'},
      ),
      request: NexaHttpRequest(
        method: NexaHttpMethod.post,
        uri: Uri.parse('https://example.com/upload'),
        headers: const <String, String>{'x-request': 'abc'},
        bodyBytes: <int>[1, 2, 3, 4],
      ),
    );

    expect(dto.method, 'POST');
    expect(dto.url, 'https://example.com/upload');
    expect(
      dto.headers,
      const <String, String>{
        'x-client': 'nexa',
        'x-request': 'abc',
      },
    );
    expect(dto.timeoutMs, 2000);
    expect(dto.bodyBytes, const <int>[1, 2, 3, 4]);
    expect(dto.toJson(), isEmpty);
  });
}
