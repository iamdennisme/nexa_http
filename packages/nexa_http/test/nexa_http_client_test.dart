import 'dart:convert';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:test/test.dart';

void main() {
  test('resolves relative URLs and maps successful responses', () async {
    final dataSource = _FakeNexaHttpNativeDataSource(
      response: NexaHttpResponse(
        statusCode: 200,
        headers: const <String, List<String>>{
          'content-type': <String>['application/json'],
        },
        bodyBytes: utf8.encode('ok'),
      ),
    );

    final client = NexaHttpClient(
      config: NexaHttpClientConfig(
        baseUrl: Uri.parse('https://example.com/api/'),
        defaultHeaders: const <String, String>{'x-sdk': 'rust-net'},
        userAgent: 'rust-net-test',
      ),
      dataSource: dataSource,
    );

    final response = await client.execute(
      NexaHttpRequest.get(uri: Uri.parse('users')),
    );

    expect(dataSource.lastRequest?.url, 'https://example.com/api/users');
    expect(dataSource.lastRequest?.headers['x-sdk'], 'rust-net');
    expect(dataSource.lastRequest?.headers['user-agent'], 'rust-net-test');
    expect(response.statusCode, 200);
    expect(response.bodyText, 'ok');
  });

  test('maps native transport errors to NexaHttpException', () async {
    final client = NexaHttpClient(
      dataSource: _FakeNexaHttpNativeDataSource(
        error: const NexaHttpException(
          code: 'timeout',
          message: 'Request timed out.',
          isTimeout: true,
        ),
      ),
    );

    expect(
      () => client.execute(
        NexaHttpRequest.get(uri: Uri.parse('https://example.com/timeout')),
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

  test('rejects relative URLs when baseUrl is missing', () async {
    final client = NexaHttpClient(
      dataSource: _FakeNexaHttpNativeDataSource(
        response: const NexaHttpResponse(
          statusCode: 200,
          headers: <String, List<String>>{},
          bodyBytes: <int>[],
        ),
      ),
    );

    expect(
      () => client.execute(NexaHttpRequest.get(uri: Uri.parse('users'))),
      throwsA(
        isA<NexaHttpException>().having(
          (exception) => exception.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('does not allow requests after close', () async {
    final client = NexaHttpClient(
      dataSource: _FakeNexaHttpNativeDataSource(
        response: const NexaHttpResponse(
          statusCode: 204,
          headers: <String, List<String>>{},
          bodyBytes: <int>[],
        ),
      ),
    );

    await client.close();

    expect(
      () => client.execute(
        NexaHttpRequest.get(uri: Uri.parse('https://example.com/ping')),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('execute is stream-first and returns NexaHttpStreamedResponse', () async {
    final client = NexaHttpClient(
      dataSource: _FakeNexaHttpNativeDataSource(
        response: const NexaHttpResponse(
          statusCode: 200,
          headers: <String, List<String>>{},
          bodyBytes: <int>[1, 2, 3],
        ),
      ),
    );

    final Future<NexaHttpStreamedResponse> Function(NexaHttpRequest) execute =
        client.execute;
    final response = await execute(
      NexaHttpRequest.get(uri: Uri.parse('https://example.com/body')),
    );
    final bytes = await response.readBytes();

    expect(bytes, <int>[1, 2, 3]);
  });
}

class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNexaHttpNativeDataSource({this.response, this.error});

  final NexaHttpResponse? response;
  final NexaHttpException? error;
  NativeHttpRequestDto? lastRequest;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<NexaHttpResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    lastRequest = request;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return response!;
  }
}
