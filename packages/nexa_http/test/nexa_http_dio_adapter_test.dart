import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:nexa_http/nexa_http_dio.dart';
import 'package:test/test.dart';

void main() {
  group('NexaHttpDioAdapter', () {
    test('requires stream-first executor response contract', () {
      Future<NexaHttpStreamedResponse> Function(HttpExecutor) signature =
          _typedExecute;
      expect(signature, isNotNull);
    });

    test('maps GET requests into NexaHttpRequest and decodes JSON responses',
        () async {
      final executor = _FakeHttpExecutor(
        handler: (request) async {
          return NexaHttpResponse(
            statusCode: 200,
            headers: const <String, List<String>>{
              'content-type': <String>[Headers.jsonContentType],
            },
            bodyBytes: utf8.encode('{"ok":true}'),
            finalUri: Uri.parse('https://example.com/v1/ping?source=dio'),
          );
        },
      );
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);

      final response = await dio.get<Map<String, dynamic>>(
        'https://example.com/v1/ping',
        queryParameters: const <String, String>{'source': 'dio'},
        options: Options(headers: const <String, Object?>{'x-sdk': 'rust-net'}),
      );

      expect(response.statusCode, 200);
      expect(response.data, <String, dynamic>{'ok': true});
      expect(executor.lastRequest?.method, NexaHttpMethod.get);
      expect(
        response.headers.value(NexaHttpDioAdapter.finalUriHeaderName),
        'https://example.com/v1/ping?source=dio',
      );
      expect(
        executor.lastRequest?.uri,
        Uri.parse('https://example.com/v1/ping?source=dio'),
      );
      expect(executor.lastRequest?.headers['x-sdk'], 'rust-net');
    });

    test('reads POST request bodies from Dio request streams', () async {
      final executor = _FakeHttpExecutor(
        handler: (request) async {
          return NexaHttpResponse(
            statusCode: 201,
            headers: const <String, List<String>>{
              'content-type': <String>[Headers.textPlainContentType],
            },
            bodyBytes: utf8.encode('created'),
          );
        },
      );
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);

      final response = await dio.post<String>(
        'https://example.com/echo',
        data: '{"message":"hello"}',
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
          headers: const <String, Object?>{
            'x-list': <String>['a', 'b'],
          },
        ),
      );

      expect(response.statusCode, 201);
      expect(response.data, 'created');
      expect(executor.lastRequest?.method, NexaHttpMethod.post);
      expect(
        utf8.decode(executor.lastRequest!.bodyBytes!),
        '{"message":"hello"}',
      );
      expect(
        executor.lastRequest?.headers['content-type'],
        Headers.jsonContentType,
      );
      expect(executor.lastRequest?.headers['x-list'], 'a, b');
    });

    test('lets Dio raise badResponse for non-2xx statuses', () async {
      final executor = _FakeHttpExecutor(
        handler: (request) async {
          return NexaHttpResponse(
            statusCode: 404,
            headers: const <String, List<String>>{
              'content-type': <String>[Headers.textPlainContentType],
            },
            bodyBytes: utf8.encode('missing'),
          );
        },
      );
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);

      await expectLater(
        () => dio.get<String>(
          'https://example.com/missing',
          options: Options(responseType: ResponseType.plain),
        ),
        throwsA(
          isA<DioException>()
              .having(
                  (error) => error.type, 'type', DioExceptionType.badResponse)
              .having((error) => error.response?.statusCode, 'statusCode', 404)
              .having((error) => error.response?.data, 'data', 'missing'),
        ),
      );
    });

    test('maps request timeouts to Dio timeout exceptions', () async {
      final executor = _FakeHttpExecutor(
        handler: (request) async {
          throw const NexaHttpException(
            code: 'timeout',
            message: 'timed out',
            isTimeout: true,
          );
        },
      );
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);

      await expectLater(
        () => dio.get<void>(
          'https://example.com/slow',
          options: Options(receiveTimeout: const Duration(milliseconds: 25)),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
    });

    test('maps CancelToken cancellations to Dio cancel errors', () async {
      final completer = Completer<NexaHttpResponse>();
      final executor = _FakeHttpExecutor(
        handler: (request) => completer.future,
      );
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);
      final cancelToken = CancelToken();

      final future = dio.get<void>(
        'https://example.com/cancel',
        cancelToken: cancelToken,
      );
      cancelToken.cancel('stop');

      await expectLater(
        future,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );

      completer.complete(
        const NexaHttpResponse(
          statusCode: 200,
          bodyBytes: <int>[],
        ),
      );
    });

    test('rejects unsupported HTTP methods', () async {
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(
          executor: _FakeHttpExecutor(
            handler: (request) async => const NexaHttpResponse(statusCode: 204),
          ),
        );

      await expectLater(
        () => dio.request<void>(
          'https://example.com/trace',
          options: Options(method: 'TRACE'),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.message,
            'message',
            contains('does not support TRACE'),
          ),
        ),
      );
    });

    test('closes the wrapped executor when the adapter is closed', () async {
      final executor = _FakeHttpExecutor(
        handler: (request) async => const NexaHttpResponse(statusCode: 204),
      );
      final adapter = NexaHttpDioAdapter(executor: executor);

      adapter.close();
      await Future<void>.delayed(Duration.zero);

      expect(executor.closeCalled, isTrue);
    });
  });
}

Future<NexaHttpStreamedResponse> _typedExecute(HttpExecutor executor) {
  return executor.execute(
    NexaHttpRequest.get(uri: Uri.parse('https://example.com/signature')),
  );
}

final class _FakeHttpExecutor implements HttpExecutor {
  _FakeHttpExecutor({required this.handler});

  final Future<NexaHttpResponse> Function(NexaHttpRequest request) handler;

  NexaHttpRequest? lastRequest;
  bool closeCalled = false;

  @override
  Future<void> close() async {
    closeCalled = true;
  }

  @override
  Future<NexaHttpResponse> execute(NexaHttpRequest request) {
    lastRequest = request;
    return handler(request);
  }
}
