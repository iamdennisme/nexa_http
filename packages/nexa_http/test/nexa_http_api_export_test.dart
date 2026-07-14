import 'dart:io';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('exports the complete v2 public HTTP API surface', () async {
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/items'))
        .header('x-sdk', 'nexa_http')
        .get()
        .build();

    expect(request.method, 'GET');
    expect(request.url, Uri.parse('https://example.com/items'));
    expect(request.headers['x-sdk'], 'nexa_http');

    final requestBody = RequestBody.takeBytes(
      Uint8List.fromList(const <int>[1, 2, 3]),
      contentType: MediaType.parse('application/octet-stream'),
    );
    final postRequest = RequestBuilder()
        .url(Uri.parse('https://example.com/upload'))
        .post(requestBody)
        .build();
    expect(postRequest.method, 'POST');
    expect(postRequest.body, same(requestBody));

    final responseBody = ResponseBody.fromString(
      'ok',
      contentType: MediaType.parse('text/plain; charset=utf-8'),
    );
    final response = Response(
      request: postRequest,
      statusCode: 200,
      headers: Headers.of(<String, List<String>>{
        'content-type': <String>['text/plain; charset=utf-8'],
      }),
      body: responseBody,
    );

    expect(response.isSuccessful, isTrue);
    expect(await response.body!.string(), 'ok');

    expect(NexaHttpClient, isA<Type>());
    expect(NexaHttpClientBuilder, isA<Type>());
    expect(Call, isA<Type>());
    expect(NexaHttpException, isA<Type>());
    expect(NexaHttpFailureKind, isA<Type>());
  });

  test('uses exact show allowlists for the API barrel and package root', () {
    const apiSymbols = <String>{
      'Call',
      'Headers',
      'MediaType',
      'NexaHttpClientBuilder',
      'NexaHttpException',
      'NexaHttpFailureKind',
      'Request',
      'RequestBody',
      'RequestBuilder',
      'Response',
      'ResponseBody',
    };
    const rootSymbols = <String>{...apiSymbols, 'NexaHttpClient'};

    expect(
      _shownSymbols(File('lib/src/api/api.dart').readAsStringSync()),
      apiSymbols,
    );
    expect(
      _shownSymbols(File('lib/nexa_http.dart').readAsStringSync()),
      rootSymbols,
    );
  });
}

Set<String> _shownSymbols(String source) {
  return RegExp(r'\bshow\s+([^;]+);', multiLine: true)
      .allMatches(source)
      .expand((match) => match.group(1)!.split(','))
      .map((symbol) => symbol.trim())
      .where((symbol) => symbol.isNotEmpty)
      .toSet();
}
