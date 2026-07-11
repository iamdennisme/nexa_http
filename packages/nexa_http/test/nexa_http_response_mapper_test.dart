import 'dart:collection';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/body/response_body_owner.dart';
import 'package:nexa_http/src/internal/transport/nexa_http_response_mapper.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:test/test.dart';

void main() {
  test(
    'maps transport response into domain response while preserving body bytes',
    () async {
      final request = RequestBuilder()
          .url(Uri.parse('https://example.com/start'))
          .get()
          .build();
      final bodyBytes = Uint8List.fromList(const <int>[104, 105]);

      final response = const NexaHttpResponseMapper().map(
        request: request,
        payload: TransportResponse(
          statusCode: 200,
          headers: <String, List<String>>{
            'content-type': <String>['text/plain; charset=utf-8'],
          },
          bodyOwner: DartResponseBodyOwner(bodyBytes),
          finalUri: Uri.parse('https://example.com/final'),
        ),
      );

      expect(response.statusCode, 200);
      expect(response.request.url, Uri.parse('https://example.com/final'));
      expect(response.finalUrl, Uri.parse('https://example.com/final'));
      expect(identical(await response.body!.bytes(), bodyBytes), isTrue);
    },
  );

  test('reuses the original request when finalUri is omitted', () {
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/start'))
        .get()
        .build();

    final response = const NexaHttpResponseMapper().map(
      request: request,
      payload: const TransportResponse(statusCode: 204),
    );

    expect(identical(response.request, request), isTrue);
    expect(response.finalUrl, request.url);
  });

  test('releases body ownership when response mapping fails', () {
    var releaseCount = 0;
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/start'))
        .get()
        .build();
    final owner = NativeResponseBodyOwner(
      Uint8List.fromList(const <int>[1, 2, 3]),
      release: () {
        releaseCount += 1;
      },
    );

    expect(
      () => const NexaHttpResponseMapper().map(
        request: request,
        payload: TransportResponse(
          statusCode: 200,
          headers: _ThrowingHeadersMap(),
          bodyOwner: owner,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(releaseCount, 1);
  });
}

final class _ThrowingHeadersMap extends MapBase<String, List<String>> {
  @override
  List<String>? operator [](Object? key) {
    throw StateError('header mapping failed');
  }

  @override
  void operator []=(String key, List<String> value) {
    throw UnsupportedError('read-only');
  }

  @override
  void clear() {
    throw UnsupportedError('read-only');
  }

  @override
  Iterable<String> get keys => const <String>[];

  @override
  List<String>? remove(Object? key) {
    throw UnsupportedError('read-only');
  }
}
