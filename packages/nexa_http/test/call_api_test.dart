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

  test('clone preserves request semantics', () {
    final client = NexaHttpClient();
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/items'))
        .header('x-request-id', 'abc')
        .post(
          RequestBody.fromString(
            '{"hello":"world"}',
            contentType: MediaType.parse('application/json; charset=utf-8'),
          ),
        )
        .build();

    final original = client.newCall(request);
    final clone = original.clone();

    expect(clone.request.method, request.method);
    expect(clone.request.url, request.url);
    expect(clone.request.headers['x-request-id'], 'abc');
    expect(clone.request.body, same(request.body));
  });

  test('cancel marks the call canceled and blocks execute before start', () {
    final client = NexaHttpClient();
    final call = client.newCall(
      RequestBuilder()
          .url(Uri.parse('https://example.com/cancel'))
          .get()
          .build(),
    );

    call.cancel();

    expect(call.isCanceled, isTrue);
    expect(call.execute(), throwsA(isA<StateError>()));
  });

  test('execute is single-shot and clone returns a fresh call', () async {
    final dataSource = _FakeNativeDataSource(
      executeResponses: const <TransportResponse>[
        TransportResponse(statusCode: 204),
        TransportResponse(statusCode: 204),
      ],
    );
    final dataSourceFactory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) => DynamicLibrary.process(),
      createDataSource: (_) => dataSource,
    );
    final engine = NexaHttpEngineManager(dataSourceFactory: dataSourceFactory);
    NexaHttpEngineManager.installForTesting(engine);
    final client = NexaHttpClient();
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/no-content'))
        .get()
        .build();
    final call = client.newCall(request);

    final firstResponse = await call.execute();

    expect(firstResponse.statusCode, 204);
    expect(call.isExecuted, isTrue);
    expect(call.execute(), throwsA(isA<StateError>()));

    final clonedCall = call.clone();
    final clonedResponse = await clonedCall.execute();
    expect(clonedResponse.statusCode, 204);
    expect(dataSource.createClientConfigs, hasLength(1));
    expect(dataSource.executeCalls, hasLength(2));
    expect(
      dataSource.executeCalls[0].clientId,
      dataSource.executeCalls[1].clientId,
    );
  });
}

final class _FakeNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNativeDataSource({required List<TransportResponse> executeResponses})
    : _executeResponses = executeResponses;

  final List<NativeHttpClientConfigDto> createClientConfigs =
      <NativeHttpClientConfigDto>[];
  final List<_ExecuteCall> executeCalls = <_ExecuteCall>[];
  final List<TransportResponse> _executeResponses;
  final int _nextClientId = 9;

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
