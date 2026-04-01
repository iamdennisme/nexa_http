import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/client/nexa_http_response_mapper.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:test/test.dart';

void main() {
  test('maps transport response into domain response while preserving body bytes', () async {
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/start'))
        .get()
        .build();
    final bodyBytes = <int>[104, 105];

    final response = const NexaHttpResponseMapper().map(
      request: request,
      payload: TransportResponse(
        statusCode: 200,
        headers: <String, List<String>>{
          'content-type': <String>['text/plain; charset=utf-8'],
        },
        bodyBytes: bodyBytes,
        finalUri: Uri.parse('https://example.com/final'),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.request.url, Uri.parse('https://example.com/final'));
    expect(response.finalUrl, Uri.parse('https://example.com/final'));
    expect(identical(await response.body!.bytes(), bodyBytes), isTrue);
    expect(await response.body!.string(), 'hi');
  });
}
