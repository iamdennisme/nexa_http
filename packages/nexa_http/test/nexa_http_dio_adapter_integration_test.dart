import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nexa_http/nexa_http_dio.dart';
import 'package:test/test.dart';

import 'support/register_host_native_runtime.dart';
import 'support/http_fixture_server.dart';

void main() {
  group('NexaHttpDioAdapter native integration', () {
    HttpFixtureServer? fixtureServer;
    Dio? dio;

    setUpAll(() async {
      await registerHostNativeRuntimeForTests();
      fixtureServer = await HttpFixtureServer.start();
      dio = Dio()
        ..httpClientAdapter = NexaHttpDioAdapter.client(
          config: const NexaHttpClientConfig(
            timeout: Duration(seconds: 2),
            userAgent: 'nexa_http_dio_integration_test',
          ),
        );
    });

    tearDownAll(() {
      dio?.close(force: true);
      return fixtureServer?.close();
    });

    test(
      'pins public executor contract to streamed responses',
      () async {
        final client = NexaHttpClient(
          config: const NexaHttpClientConfig(
            timeout: Duration(seconds: 2),
            userAgent: 'nexa_http_dio_integration_test',
          ),
        );
        addTearDown(client.close);

        await expectLater(
          _readStreamFirstBodyText(
            client,
            fixtureServer!.uri(
              '/get',
              <String, String>{'source': 'dio_streaming_pending'},
            ),
          ),
          completion(contains('"message":"hello from fixture"')),
        );
      },
      tags: const <String>['dio_streaming_pending'],
    );

    test(
      'supports the common HTTP method matrix through Dio',
      () async {
        final getResponse = await dio!.get<Map<String, dynamic>>(
          fixtureServer!.uri(
            '/get',
            <String, String>{'source': 'dio_integration'},
          ).toString(),
        );
        expect(getResponse.statusCode, HttpStatus.ok);
        expect(getResponse.data?['message'], 'hello from fixture');
        expect(getResponse.data?['query']['source'], 'dio_integration');

        final postPayload = '{"method":"POST"}';
        final postResponse = await dio!.post<String>(
          fixtureServer!.uri('/echo').toString(),
          data: postPayload,
          options: Options(
            contentType: Headers.jsonContentType,
            responseType: ResponseType.plain,
          ),
        );
        expect(postResponse.statusCode, HttpStatus.created);
        expect(postResponse.data, postPayload);
        expect(
          postResponse.headers.map['x-request-method'],
          contains('POST'),
        );

        for (final method in <String>['PUT', 'PATCH']) {
          final payload = '{"method":"$method"}';
          final response = await dio!.request<String>(
            fixtureServer!.uri('/echo').toString(),
            data: payload,
            options: Options(
              method: method,
              contentType: Headers.jsonContentType,
              responseType: ResponseType.plain,
            ),
          );
          expect(response.statusCode, HttpStatus.ok);
          expect(response.data, payload);
          expect(response.headers.map['x-request-method'], contains(method));
        }

        final deleteResponse = await dio!.delete<Map<String, dynamic>>(
          fixtureServer!.uri('/delete').toString(),
        );
        expect(deleteResponse.statusCode, HttpStatus.ok);
        expect(deleteResponse.data?['deleted'], isTrue);

        final headResponse = await dio!.head<String>(
          fixtureServer!.uri('/head').toString(),
          options: Options(responseType: ResponseType.plain),
        );
        expect(headResponse.statusCode, HttpStatus.ok);
        expect(headResponse.data, anyOf(isNull, isEmpty));
        expect(headResponse.headers.map['x-fixture-head'], contains('true'));

        final optionsResponse = await dio!.request<void>(
          fixtureServer!.uri('/options').toString(),
          options: Options(
            method: 'OPTIONS',
            responseType: ResponseType.plain,
          ),
        );
        expect(optionsResponse.statusCode, HttpStatus.noContent);
        expect(
          optionsResponse.headers.map[HttpHeaders.allowHeader.toLowerCase()],
          contains(contains('DELETE')),
        );
      },
    );

    test(
      'preserves representative status codes when Dio validateStatus allows them',
      () async {
        const statusCodes = <int>[
          200,
          201,
          202,
          204,
          400,
          401,
          403,
          404,
          429,
          500,
          502,
          503,
        ];

        for (final statusCode in statusCodes) {
          final response = await dio!.get<String>(
            fixtureServer!.uri('/status/$statusCode').toString(),
            options: Options(
              responseType: ResponseType.plain,
              validateStatus: (_) => true,
            ),
          );

          expect(response.statusCode, statusCode);
          if (statusCode == HttpStatus.noContent) {
            expect(response.data, anyOf(isNull, isEmpty));
          } else {
            expect(response.data, contains('"status_code":$statusCode'));
          }
        }
      },
    );

    test(
      'follows GET redirects through the Rust core',
      () async {
        for (final statusCode in <int>[301, 302, 303, 307, 308]) {
          final expectedFinalUri = fixtureServer!.uri(
            '/get',
            <String, String>{'source': 'redirected_$statusCode'},
          );
          final response = await dio!.get<Map<String, dynamic>>(
            fixtureServer!.uri(
              '/redirect/$statusCode',
              <String, String>{'location': expectedFinalUri.toString()},
            ).toString(),
          );

          expect(response.statusCode, HttpStatus.ok);
          expect(response.data?['query']['source'], 'redirected_$statusCode');
          expect(
            response.headers.value(NexaHttpDioAdapter.finalUriHeaderName),
            expectedFinalUri.toString(),
          );
        }
      },
    );

    test(
      'follows POST redirects through the Rust core',
      () async {
        const payload = '{"message":"redirect me"}';
        final expectations = <int, String>{
          301: 'GET',
          302: 'GET',
          303: 'GET',
          307: 'POST',
          308: 'POST',
        };

        for (final entry in expectations.entries) {
          final expectedFinalUri = fixtureServer!.uri(
            '/redirect-target',
            <String, String>{'source': 'redirected_${entry.key}'},
          );
          final response = await dio!.post<Map<String, dynamic>>(
            fixtureServer!.uri(
              '/redirect/${entry.key}',
              <String, String>{'location': expectedFinalUri.toString()},
            ).toString(),
            data: payload,
            options: Options(contentType: Headers.jsonContentType),
          );

          expect(response.statusCode, HttpStatus.ok);
          expect(response.data?['method'], entry.value);
          expect(
            response.headers.value(NexaHttpDioAdapter.finalUriHeaderName),
            expectedFinalUri.toString(),
          );
          if (entry.value == 'POST') {
            expect(response.data?['body_text'], payload);
          } else {
            expect(response.data?['body_text'], isEmpty);
          }
        }
      },
    );

    test(
      'maps Rust request timeouts to Dio receiveTimeout',
      () async {
        await expectLater(
          () => dio!.get<void>(
            fixtureServer!.uri(
              '/slow',
              <String, String>{'delay_ms': '200'},
            ).toString(),
            options: Options(
              receiveTimeout: const Duration(milliseconds: 20),
            ),
          ),
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

    test(
      'keeps byte responses intact for Dio callers',
      () async {
        final payload = utf8.encode('{"method":"PATCH"}');
        final response = await dio!.request<List<int>>(
          fixtureServer!.uri('/echo').toString(),
          data: jsonEncode(<String, String>{'method': 'PATCH'}),
          options: Options(
            method: 'PATCH',
            contentType: Headers.jsonContentType,
            responseType: ResponseType.bytes,
          ),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(response.data, payload);
      },
    );
  });
}

Future<String> _readStreamFirstBodyText(HttpExecutor executor, Uri uri) async {
  final response = await executor.execute(NexaHttpRequest.get(uri: uri));
  final bytes = await (response as dynamic).readBytes() as List<int>;
  return utf8.decode(bytes);
}
