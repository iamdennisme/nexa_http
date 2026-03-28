import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:nexa_http/nexa_http_dio.dart';
import 'package:test/test.dart';

void main() {
  group('NexaHttpDioAdapter', () {
    test(
      'passes ResponseType.stream through without buffering the body',
      () async {
        final bodyController = StreamController<Uint8List>();
        addTearDown(() async {
          if (!bodyController.isClosed) {
            await bodyController.close();
          }
        });

        final executor = _FakeHttpExecutor(
          handler: (request) async => _streamedResponse(
            statusCode: 200,
            bodyStream: bodyController.stream,
          ),
        );
        final dio = Dio()
          ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);

        final response = await dio
            .get<ResponseBody>(
              'https://example.com/stream',
              options: Options(responseType: ResponseType.stream),
            )
            .timeout(_shortTestTimeout);
        final chunksFuture = response.data!.stream.toList();

        bodyController.add(Uint8List.fromList(<int>[1, 2]));
        bodyController.add(Uint8List.fromList(<int>[3, 4]));
        await bodyController.close();

        final chunks = await chunksFuture;
        expect(
          chunks.map((chunk) => chunk.toList()).toList(growable: false),
          <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ],
        );
      },
    );

    test(
      'maps GET requests into NexaHttpRequest and decodes JSON responses',
      () async {
        final executor = _FakeHttpExecutor(
          handler: (request) async {
            return _streamedResponse(
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
          options: Options(
            headers: const <String, Object?>{'x-sdk': 'rust-net'},
          ),
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
      },
    );

    test('reads POST request bodies from Dio request streams', () async {
      final executor = _FakeHttpExecutor(
        handler: (request) async {
          return _streamedResponse(
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
          return _streamedResponse(
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
                (error) => error.type,
                'type',
                DioExceptionType.badResponse,
              )
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

    test(
      'maps streamed body timeout errors to Dio timeout exceptions',
      () async {
        final bodyController = StreamController<Uint8List>();
        addTearDown(() async {
          if (!bodyController.isClosed) {
            await bodyController.close();
          }
        });

        final executor = _FakeHttpExecutor(
          handler: (request) async => _streamedResponse(
            statusCode: 200,
            bodyStream: bodyController.stream,
          ),
        );
        final dio = Dio()
          ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);

        final response = await dio
            .get<ResponseBody>(
              'https://example.com/stream-timeout',
              options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: const Duration(milliseconds: 25),
              ),
            )
            .timeout(_shortTestTimeout);
        final bodyBytesFuture = response.data!.stream
            .expand((chunk) => chunk)
            .toList();

        bodyController.add(Uint8List.fromList(<int>[1]));
        bodyController.addError(
          const NexaHttpException(
            code: 'timeout',
            message: 'timed out',
            isTimeout: true,
          ),
        );
        await bodyController.close();

        await expectLater(
          bodyBytesFuture,
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.receiveTimeout,
            ),
          ),
        );
      },
    );

    test('maps CancelToken cancellations to Dio cancel errors', () async {
      final completer = Completer<NexaHttpStreamedResponse>();
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
        _streamedResponse(statusCode: 200, bodyBytes: <int>[]),
      );
    });

    test(
      'maps CancelToken cancellations while receiving ResponseType.stream bodies',
      () async {
        final bodyController = StreamController<Uint8List>();
        addTearDown(() async {
          if (!bodyController.isClosed) {
            await bodyController.close();
          }
        });

        final executor = _FakeHttpExecutor(
          handler: (request) async => _streamedResponse(
            statusCode: 200,
            bodyStream: bodyController.stream,
          ),
        );
        final dio = Dio()
          ..httpClientAdapter = NexaHttpDioAdapter(executor: executor);
        final cancelToken = CancelToken();

        final response = await dio
            .get<ResponseBody>(
              'https://example.com/stream-cancel',
              cancelToken: cancelToken,
              options: Options(responseType: ResponseType.stream),
            )
            .timeout(_shortTestTimeout);
        final drainFuture = response.data!.stream.drain<void>();

        bodyController.add(Uint8List.fromList(<int>[1]));
        cancelToken.cancel('stop');
        await bodyController.close();

        await expectLater(
          drainFuture,
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
      },
    );

    test('rejects unsupported HTTP methods', () async {
      final dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter(
          executor: _FakeHttpExecutor(
            handler: (request) async => _streamedResponse(statusCode: 204),
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
        handler: (request) async => _streamedResponse(statusCode: 204),
      );
      final adapter = NexaHttpDioAdapter(executor: executor);

      adapter.close();
      await Future<void>.delayed(Duration.zero);

      expect(executor.closeCalled, isTrue);
    });
  });
}

const _shortTestTimeout = Duration(milliseconds: 200);

final class _FakeHttpExecutor implements HttpExecutor {
  _FakeHttpExecutor({required this.handler});

  final Future<NexaHttpStreamedResponse> Function(NexaHttpRequest request)
  handler;

  NexaHttpRequest? lastRequest;
  bool closeCalled = false;

  @override
  Future<void> close() async {
    closeCalled = true;
  }

  @override
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request) {
    lastRequest = request;
    return handler(request);
  }
}

NexaHttpStreamedResponse _streamedResponse({
  required int statusCode,
  Map<String, List<String>> headers = const <String, List<String>>{},
  List<int> bodyBytes = const <int>[],
  Stream<Uint8List>? bodyStream,
  Uri? finalUri,
}) {
  final effectiveBodyStream =
      bodyStream ?? Stream<Uint8List>.value(Uint8List.fromList(bodyBytes));
  return NexaHttpStreamedResponse(
    statusCode: statusCode,
    headers: headers,
    finalUri: finalUri,
    contentLength: bodyBytes.length,
    bodyStream: effectiveBodyStream,
  );
}
