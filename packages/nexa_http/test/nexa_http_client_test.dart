import 'dart:ffi';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/engine/nexa_http_engine_manager.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    NexaHttpEngineManager.resetForTesting();
  });

  test('constructs synchronously and exposes configured defaults', () {
    final client = NexaHttpClientBuilder()
        .baseUrl(Uri.parse('https://api.example.com/'))
        .callTimeout(const Duration(seconds: 3))
        .userAgent('test-agent')
        .header('x-sdk', 'nexa_http')
        .build();

    expect(client, isA<NexaHttpClient>());
    expect(client.baseUrl, Uri.parse('https://api.example.com/'));
    expect(client.callTimeout, const Duration(seconds: 3));
    expect(client.userAgent, 'test-agent');
    expect(client.defaultHeaders['x-sdk'], 'nexa_http');
  });

  test('newCall lazily opens a native lease on first execute', () async {
    final responseBytes = <int>[104, 105];
    final dataSource = _FakeNativeDataSource(
      executeResponses: <TransportResponse>[
        TransportResponse(
          statusCode: 200,
          headers: const <String, List<String>>{
            'content-type': <String>['application/json; charset=utf-8'],
          },
          bodyBytes: responseBytes,
          finalUri: Uri.parse('https://example.com/ok'),
        ),
      ],
    );
    final dataSourceFactory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) => DynamicLibrary.process(),
      createDataSource: (_) => dataSource,
    );
    final engine = NexaHttpEngineManager(dataSourceFactory: dataSourceFactory);
    NexaHttpEngineManager.installForTesting(engine);
    final client = NexaHttpClientBuilder()
        .callTimeout(const Duration(seconds: 1))
        .userAgent('test-agent')
        .build();

    final call = client.newCall(
      RequestBuilder().url(Uri.parse('https://example.com/ok')).get().build(),
    );

    expect(dataSource.createClientConfigs, isEmpty);

    final response = await call.execute();

    expect(response.statusCode, 200);
    final bodyBytes = await response.body!.bytes();
    expect(identical(bodyBytes, responseBytes), isTrue);
    expect(await response.body!.string(), 'hi');
    expect(response.finalUrl, Uri.parse('https://example.com/ok'));
    expect(dataSource.createClientConfigs, hasLength(1));
    final openConfig = dataSource.createClientConfigs.single;
    expect(openConfig.timeoutMs, 1000);
    expect(openConfig.userAgent, 'test-agent');

    expect(dataSource.executeCalls, hasLength(1));
    final executeCall = dataSource.executeCalls.single;
    expect(executeCall.clientId, 41);
    expect(executeCall.request.method, 'GET');
    expect(executeCall.request.url, 'https://example.com/ok');
  });

  test(
    'normalizes default header names before lease caching so equivalent clients reuse one native client',
    () async {
      final dataSource = _FakeNativeDataSource(
        executeResponses: const <TransportResponse>[
          TransportResponse(statusCode: 204),
          TransportResponse(statusCode: 204),
        ],
      );
      final dataSourceFactory = NexaHttpNativeDataSourceFactory(
        loadDynamicLibrary: ({String? explicitPath}) =>
            DynamicLibrary.process(),
        createDataSource: (_) => dataSource,
      );
      final engine = NexaHttpEngineManager(
        dataSourceFactory: dataSourceFactory,
      );
      NexaHttpEngineManager.installForTesting(engine);

      final firstClient = NexaHttpClient(
        defaultHeaders: const <String, String>{'X-SDK': 'nexa_http'},
      );
      final secondClient = NexaHttpClient(
        defaultHeaders: const <String, String>{'x-sdk': 'nexa_http'},
      );
      final request = RequestBuilder()
          .url(Uri.parse('https://example.com/ping'))
          .get()
          .build();

      await firstClient.newCall(request).execute();
      await secondClient.newCall(request).execute();

      expect(dataSource.createClientConfigs, hasLength(1));
      expect(dataSource.executeCalls, hasLength(2));
      expect(dataSource.executeCalls[0].clientId,
          dataSource.executeCalls[1].clientId);
      final firstHeaders = dataSource.executeCalls[0].request.headers
          .map((header) => (header.key, header.value))
          .toList();
      final secondHeaders = dataSource.executeCalls[1].request.headers
          .map((header) => (header.key, header.value))
          .toList();
      expect(
        firstHeaders,
        contains(('x-sdk', 'nexa_http')),
      );
      expect(
        secondHeaders,
        contains(('x-sdk', 'nexa_http')),
      );
    },
  );
}

final class _FakeNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNativeDataSource({required List<TransportResponse> executeResponses})
      : _executeResponses = executeResponses;

  final List<NativeHttpClientConfigDto> createClientConfigs =
      <NativeHttpClientConfigDto>[];
  final List<_ExecuteCall> executeCalls = <_ExecuteCall>[];
  final List<TransportResponse> _executeResponses;
  final int _nextClientId = 41;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    createClientConfigs.add(config);
    return _nextClientId;
  }

  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    executeCalls.add(_ExecuteCall(clientId: clientId, request: request));
    return _executeResponses[executeCalls.length - 1];
  }

  @override
  void closeClient(int clientId) {}
}

final class _ExecuteCall {
  const _ExecuteCall({required this.clientId, required this.request});

  final int clientId;
  final NativeHttpRequestDto request;
}
