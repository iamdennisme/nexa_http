import 'package:nexa_http/src/data/mappers/native_http_request_mapper.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/config/client_options.dart';
import 'package:test/test.dart';

void main() {
  test('encodes structured native request fields as a typed dto', () {
    final request = NativeHttpRequestMapper.toDto(
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

    expect(request.method, 'POST');
    expect(request.url, 'https://example.com/upload');
    expect(
      request.headers.map((header) => (header.key, header.value)).toList(),
      equals(const <(String, String)>[
        ('x-client', 'nexa'),
        ('x-request', 'abc'),
      ]),
    );
    expect(request.timeoutMs, 2000);
    expect(request.bodyBytes, const <int>[1, 2, 3, 4]);
  });

  test('preserves repeated request headers without projecting through a map',
      () {
    final request = NativeHttpRequestMapper.toDto(
      clientConfig: const ClientOptions(
        defaultHeaders: <String, String>{
          'x-client': 'nexa',
          'accept': 'text/plain',
        },
        userAgent: 'sdk-agent',
      ),
      request: RequestBuilder()
          .url(Uri.parse('https://example.com/upload'))
          .addHeader('accept', 'application/json')
          .addHeader('accept', 'application/problem+json')
          .header('user-agent', 'request-agent')
          .post(
            RequestBody.bytes(
              <int>[1, 2, 3, 4],
              contentType: MediaType.parse('application/octet-stream'),
            ),
          )
          .build(),
    );

    expect(
      request.headers.map((header) => (header.key, header.value)).toList(),
      equals(const <(String, String)>[
        ('x-client', 'nexa'),
        ('accept', 'application/json'),
        ('accept', 'application/problem+json'),
        ('user-agent', 'request-agent'),
        ('content-type', 'application/octet-stream'),
      ]),
    );
  });
}
