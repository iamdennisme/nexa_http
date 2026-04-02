import 'dart:typed_data';

import 'package:nexa_http/src/data/mappers/native_http_request_mapper.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/config/client_options.dart';
import 'package:test/test.dart';

void main() {
  test('omits lease-level defaults from request dto fields', () {
    final request = NativeHttpRequestMapper.toDto(
      clientConfig: const ClientOptions(
        timeout: Duration(seconds: 2),
        defaultHeaders: <String, String>{'x-client': 'nexa'},
      ),
      request: RequestBuilder()
          .url(Uri.parse('https://example.com/upload'))
          .header('x-request', 'abc')
          .post(RequestBody.bytes(Uint8List.fromList(<int>[1, 2, 3, 4])))
          .build(),
    );

    expect(request.method, 'POST');
    expect(request.url, 'https://example.com/upload');
    expect(
      request.headers.map((header) => (header.key, header.value)).toList(),
      equals(const <(String, String)>[('x-request', 'abc')]),
    );
    expect(request.timeoutMs, isNull);
    expect(request.bodyBytes, Uint8List.fromList(const <int>[1, 2, 3, 4]));
    expect(request.bodyBytes, isA<Uint8List>());
  });

  test(
    'preserves repeated request overrides without projecting through a map',
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
                Uint8List.fromList(<int>[1, 2, 3, 4]),
                contentType: MediaType.parse('application/octet-stream'),
              ),
            )
            .build(),
      );

      expect(
        request.headers.map((header) => (header.key, header.value)).toList(),
        equals(const <(String, String)>[
          ('accept', 'application/json'),
          ('accept', 'application/problem+json'),
          ('user-agent', 'request-agent'),
          ('content-type', 'application/octet-stream'),
        ]),
      );
    },
  );

  test('keeps request timeout override explicit when present', () {
    final request = NativeHttpRequestMapper.toDto(
      clientConfig: const ClientOptions(timeout: Duration(seconds: 2)),
      request: RequestBuilder()
          .url(Uri.parse('https://example.com/upload'))
          .timeout(const Duration(milliseconds: 250))
          .post(RequestBody.bytes(Uint8List.fromList(const <int>[1])))
          .build(),
    );

    expect(request.timeoutMs, 250);
  });
}
