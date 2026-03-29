import 'dart:convert';
import 'dart:io';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

import 'support/register_host_native_runtime.dart';
import 'support/http_fixture_server.dart';

const skipReason =
    'Binary fixture coverage is not enabled in this environment.';

void main() {
  group('NexaHttpClient native integration', () {
    HttpFixtureServer? fixtureServer;
    NexaHttpClient? client;

    setUpAll(() async {
      await registerHostNativeRuntimeForTests();
      fixtureServer = await HttpFixtureServer.start();
      client = NexaHttpClient(
        config: const NexaHttpClientConfig(
          timeout: Duration(seconds: 2),
          userAgent: 'nexa_http_integration_test',
        ),
      );
    });

    tearDownAll(() async {
      await client?.close();
      await fixtureServer?.close();
    });

    test('executes GET requests against the local fixture server', () async {
      final response = await client!.execute(
        NexaHttpRequest.get(
          uri: fixtureServer!.uri('/get', <String, String>{
            'source': 'integration',
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], isNotNull);
      expect(
        response.headers['content-type']!,
        contains(contains('application/json')),
      );
      expect(response.bodyText, contains('hello from fixture'));
      expect(response.bodyText, contains('"source":"integration"'));
    });

    test('supports direct 2xx response matrix', () async {
      const successStatuses = <int>[200, 201, 202, 204];
      for (final status in successStatuses) {
        final response = await client!.execute(
          NexaHttpRequest.get(uri: fixtureServer!.uri('/status/$status')),
        );

        expect(
          response.statusCode,
          status,
          reason: 'Expected status $status to round-trip through Rust.',
        );

        if (status == HttpStatus.noContent) {
          expect(response.bodyBytes, isEmpty);
        } else {
          expect(response.bodyText, contains('"status_code":$status'));
        }
      }
    });

    test(
      'executes POST/PUT/PATCH requests and preserves body transfer',
      () async {
        Future<void> expectEcho({
          required NexaHttpMethod method,
          required int expectedStatusCode,
          required String body,
        }) async {
          final response = await client!.execute(
            NexaHttpRequest(
              method: method,
              uri: fixtureServer!.uri('/echo'),
              bodyBytes: utf8.encode(body),
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            ),
          );

          expect(response.statusCode, expectedStatusCode);
          expect(
            response.headers['x-request-method'],
            contains(method.wireValue),
          );
          expect(response.bodyText, body);
        }

        await expectEcho(
          method: NexaHttpMethod.post,
          expectedStatusCode: HttpStatus.created,
          body: '{"method":"POST"}',
        );
        await expectEcho(
          method: NexaHttpMethod.put,
          expectedStatusCode: HttpStatus.ok,
          body: '{"method":"PUT"}',
        );
        await expectEcho(
          method: NexaHttpMethod.patch,
          expectedStatusCode: HttpStatus.ok,
          body: '{"method":"PATCH"}',
        );
      },
    );

    test('supports DELETE, HEAD, and OPTIONS', () async {
      final deleteResponse = await client!.execute(
        NexaHttpRequest(
          method: NexaHttpMethod.delete,
          uri: fixtureServer!.uri('/delete'),
        ),
      );
      expect(deleteResponse.statusCode, HttpStatus.ok);
      expect(deleteResponse.bodyText, contains('"deleted":true'));

      final headResponse = await client!.execute(
        NexaHttpRequest(
          method: NexaHttpMethod.head,
          uri: fixtureServer!.uri('/head'),
        ),
      );
      expect(headResponse.statusCode, HttpStatus.ok);
      expect(headResponse.bodyBytes, isEmpty);
      expect(headResponse.headers['x-fixture-head'], contains('true'));

      final optionsResponse = await client!.execute(
        NexaHttpRequest(
          method: NexaHttpMethod.options,
          uri: fixtureServer!.uri('/options'),
          bodyBytes: const <int>[],
        ),
      );
      expect(optionsResponse.statusCode, HttpStatus.noContent);
      expect(optionsResponse.bodyBytes, isEmpty);
      expect(
        optionsResponse.headers[HttpHeaders.allowHeader.toLowerCase()],
        contains(contains('DELETE')),
      );
    });

    test(
      'follows all supported redirects and returns the final 2xx response',
      () async {
        const redirectStatuses = <int>[301, 302, 303, 307, 308];
        for (final status in redirectStatuses) {
          final expectedFinalUri = fixtureServer!.uri('/get', <String, String>{
            'source': 'redirected_$status',
          });
          final response = await client!.execute(
            NexaHttpRequest.get(
              uri: fixtureServer!.uri('/redirect/$status', <String, String>{
                'location': expectedFinalUri.toString(),
              }),
            ),
          );

          expect(response.statusCode, HttpStatus.ok);
          expect(response.bodyText, contains('"source":"redirected_$status"'));
          expect(response.finalUri, expectedFinalUri);
        }
      },
    );

    test(
      'follows POST redirects with the reqwest method policy and exposes finalUri',
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
          final response = await client!.execute(
            NexaHttpRequest(
              method: NexaHttpMethod.post,
              uri: fixtureServer!.uri(
                '/redirect/${entry.key}',
                <String, String>{'location': expectedFinalUri.toString()},
              ),
              bodyBytes: utf8.encode(payload),
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            ),
          );

          expect(response.statusCode, HttpStatus.ok);
          expect(response.finalUri, expectedFinalUri);
          final responseJson =
              jsonDecode(response.bodyText) as Map<String, dynamic>;
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
        final response = await client!.execute(
          NexaHttpRequest.get(uri: fixtureServer!.uri('/status/$status')),
        );
        expect(
          response.statusCode,
          status,
          reason: 'Expected status $status to stay intact.',
        );
        expect(response.bodyText, contains('"status_code":$status'));
      }
    });

    test('downloads raw binary payloads without base64 transport', () async {
      final response = await client!.execute(
        NexaHttpRequest.get(
          uri: fixtureServer!.uri('/bytes', <String, String>{
            'size': '32',
            'seed': '11',
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.headers[HttpHeaders.contentTypeHeader.toLowerCase()],
        contains('application/octet-stream'),
      );
      expect(
        response.bodyBytes,
        List<int>.generate(32, (index) => (11 + index) % 256),
      );
    }, skip: skipReason);

    test('maps local fixture timeouts to NexaHttpException', () async {
      expect(
        () => client!.execute(
          NexaHttpRequest.get(
            uri: fixtureServer!.uri('/slow', <String, String>{
              'delay_ms': '200',
            }),
            timeout: const Duration(milliseconds: 20),
          ),
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
