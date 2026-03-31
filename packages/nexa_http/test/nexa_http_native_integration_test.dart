import 'dart:convert';
import 'dart:io';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

import 'support/http_fixture_server.dart';
import 'support/register_host_native_runtime.dart';

void main() {
  group('NexaHttpClient native integration', () {
    HttpFixtureServer? fixtureServer;
    late NexaHttpClient client;

    setUpAll(() async {
      await registerHostNativeRuntimeForTests();
      fixtureServer = await HttpFixtureServer.start();
      client = NexaHttpClientBuilder()
          .callTimeout(const Duration(seconds: 2))
          .userAgent('nexa_http_integration_test')
          .build();
    });

    tearDownAll(() async {
      await fixtureServer?.close();
    });

    test('executes GET requests against the local fixture server', () async {
      final response = await _execute(
        client,
        RequestBuilder()
            .url(
              fixtureServer!.uri('/get', <String, String>{
                'source': 'integration',
              }),
            )
            .get()
            .build(),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.header('content-type'), isNotNull);
      expect(response.header('content-type'), contains('application/json'));
      final body = await response.body!.string();
      expect(body, contains('hello from fixture'));
      expect(body, contains('"source":"integration"'));
    });

    test('supports direct 2xx response matrix', () async {
      const successStatuses = <int>[200, 201, 202, 204];
      for (final status in successStatuses) {
        final response = await _execute(
          client,
          RequestBuilder()
              .url(fixtureServer!.uri('/status/$status'))
              .get()
              .build(),
        );

        expect(
          response.statusCode,
          status,
          reason: 'Expected status $status to round-trip through Rust.',
        );

        if (status == HttpStatus.noContent) {
          expect(await response.body!.bytes(), isEmpty);
        } else {
          expect(
              await response.body!.string(), contains('"status_code":$status'));
        }
      }
    });

    test('executes POST/PUT/PATCH requests and preserves body transfer',
        () async {
      Future<void> expectEcho({
        required String method,
        required int expectedStatusCode,
        required String body,
      }) async {
        final response = await _execute(
          client,
          RequestBuilder()
              .url(fixtureServer!.uri('/echo'))
              .method(
                method,
                RequestBody.fromString(
                  body,
                  contentType:
                      MediaType.parse('application/json; charset=utf-8'),
                ),
              )
              .build(),
        );

        expect(response.statusCode, expectedStatusCode);
        expect(response.header('x-request-method'), contains(method));
        expect(await response.body!.string(), body);
      }

      await expectEcho(
        method: 'POST',
        expectedStatusCode: HttpStatus.created,
        body: '{"method":"POST"}',
      );
      await expectEcho(
        method: 'PUT',
        expectedStatusCode: HttpStatus.ok,
        body: '{"method":"PUT"}',
      );
      await expectEcho(
        method: 'PATCH',
        expectedStatusCode: HttpStatus.ok,
        body: '{"method":"PATCH"}',
      );
    });

    test('supports DELETE, HEAD, and OPTIONS', () async {
      final deleteResponse = await _execute(
        client,
        RequestBuilder().url(fixtureServer!.uri('/delete')).delete().build(),
      );
      expect(deleteResponse.statusCode, HttpStatus.ok);
      expect(await deleteResponse.body!.string(), contains('"deleted":true'));

      final headResponse = await _execute(
        client,
        RequestBuilder().url(fixtureServer!.uri('/head')).head().build(),
      );
      expect(headResponse.statusCode, HttpStatus.ok);
      expect(await headResponse.body!.bytes(), isEmpty);
      expect(headResponse.header('x-fixture-head'), contains('true'));

      final optionsResponse = await _execute(
        client,
        RequestBuilder()
            .url(fixtureServer!.uri('/options'))
            .method('OPTIONS', RequestBody.bytes(const <int>[]))
            .build(),
      );
      expect(optionsResponse.statusCode, HttpStatus.noContent);
      expect(await optionsResponse.body!.bytes(), isEmpty);
      expect(
        optionsResponse.header(HttpHeaders.allowHeader),
        contains('DELETE'),
      );
    });

    test('follows all supported redirects and returns the final 2xx response',
        () async {
      const redirectStatuses = <int>[301, 302, 303, 307, 308];
      for (final status in redirectStatuses) {
        final expectedFinalUri = fixtureServer!.uri('/get', <String, String>{
          'source': 'redirected_$status',
        });
        final response = await _execute(
          client,
          RequestBuilder()
              .url(
                fixtureServer!.uri('/redirect/$status', <String, String>{
                  'location': expectedFinalUri.toString(),
                }),
              )
              .get()
              .build(),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(await response.body!.string(),
            contains('"source":"redirected_$status"'));
        expect(response.finalUrl, expectedFinalUri);
      }
    });

    test(
      'follows POST redirects with the reqwest method policy and exposes finalUrl',
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
          final response = await _execute(
            client,
            RequestBuilder()
                .url(
                  fixtureServer!.uri(
                    '/redirect/${entry.key}',
                    <String, String>{'location': expectedFinalUri.toString()},
                  ),
                )
                .post(
                  RequestBody.fromString(
                    payload,
                    contentType: MediaType.parse(
                      'application/json; charset=utf-8',
                    ),
                  ),
                )
                .build(),
          );

          expect(response.statusCode, HttpStatus.ok);
          expect(response.finalUrl, expectedFinalUri);
          final responseJson =
              jsonDecode(await response.body!.string()) as Map<String, dynamic>;
          expect(responseJson['method'], entry.value);
          if (entry.value == 'POST') {
            expect(responseJson['body_text'], payload);
          } else {
            expect(responseJson['body_text'], isEmpty);
          }
        }
      },
    );

    test('preserves representative 4xx and 5xx status responses', () async {
      const errorStatuses = <int>[400, 401, 403, 404, 429, 500, 502, 503];
      for (final status in errorStatuses) {
        final response = await _execute(
          client,
          RequestBuilder()
              .url(fixtureServer!.uri('/status/$status'))
              .get()
              .build(),
        );
        expect(
          response.statusCode,
          status,
          reason: 'Expected status $status to stay intact.',
        );
        expect(
            await response.body!.string(), contains('"status_code":$status'));
      }
    });

    test('maps local fixture timeouts to NexaHttpException', () async {
      expect(
        () => _execute(
          client,
          RequestBuilder()
              .url(
                fixtureServer!.uri('/slow', <String, String>{
                  'delay_ms': '200',
                }),
              )
              .timeout(const Duration(milliseconds: 20))
              .get()
              .build(),
        ),
        throwsA(
          isA<NexaHttpException>().having(
            (exception) => exception.isTimeout,
            'isTimeout',
            isTrue,
          ),
        ),
      );
    });
  });
}

Future<Response> _execute(NexaHttpClient client, Request request) {
  return client.newCall(request).execute();
}
