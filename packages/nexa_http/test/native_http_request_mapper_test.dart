import 'package:nexa_http/src/data/mappers/native_http_request_mapper.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/config/client_options.dart';
import 'package:test/test.dart';

void main() {
  test('encodes structured native request fields without request json', () async {
    final payload = await NativeHttpRequestMapper.toPayload(
      clientConfig: const ClientOptions(
        timeout: Duration(seconds: 2),
        defaultHeaders: <String, String>{'x-client': 'nexa'},
      ),
      request: RequestBuilder()
          .url(Uri.parse('https://example.com/upload'))
          .header('x-request', 'abc')
          .post(RequestBody.bytes(<int>[1, 2, 3, 4]))
          .build(),
    );

    expect(payload['method'], 'POST');
    expect(payload['url'], 'https://example.com/upload');
    expect(
      payload['headers'],
      const <String, String>{
        'x-client': 'nexa',
        'x-request': 'abc',
      },
    );
    expect(payload['timeout_ms'], 2000);
    expect(payload['bodyBytes'], const <int>[1, 2, 3, 4]);
    expect(payload.containsKey('body_base64'), isFalse);
  });
}
