import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/native_transport/native_http_client_config_dto.dart';
import 'package:nexa_http/src/internal/native_transport/native_http_request_dto.dart';
import 'package:nexa_http/src/internal/native_transport/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/config/client_options.dart';
import 'package:nexa_http/src/internal/native_transport/nexa_http_native_transport.dart';
import 'package:nexa_http/src/internal/native_transport/transport_response.dart';
import 'package:nexa_http/src/internal/native_transport/nexa_http_native_data_source_factory.dart';
import 'package:test/test.dart';

import 'support/fake_native_bindings.dart';

void main() {
  test(
    'reuses one native lease across repeated executions and disposes once',
    () async {
      final dataSource = _FakeNativeDataSource(
        executeResponses: const <TransportResponse>[
          TransportResponse(statusCode: 204),
          TransportResponse(statusCode: 204),
        ],
      );
      final factory = NexaHttpNativeDataSourceFactory(
        resolveBindings: FakeNativeBindings.new,
        createDataSource: (_) => dataSource,
      );
      final transport = NexaHttpNativeTransport(
        options: const ClientOptions(
          defaultHeaders: <String, String>{'x-sdk': 'nexa_http'},
        ),
        dataSourceFactory: factory,
      );
      final request = _request('https://example.com/ping');

      await transport.execute(request);
      await transport.execute(request);
      await transport.close();

      expect(dataSource.createClientConfigs, hasLength(1));
      expect(
        dataSource.createClientConfigs.single.defaultHeaders,
        <String, String>{'x-sdk': 'nexa_http'},
      );
      expect(dataSource.executeCalls, hasLength(2));
      expect(
        dataSource.executeCalls[0].clientId,
        dataSource.executeCalls[1].clientId,
      );
      expect(dataSource.closedClientIds, <int>[41]);
      expect(dataSource.disposeCount, 1);
    },
  );
}

final class _FakeNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNativeDataSource({required List<TransportResponse> executeResponses})
    : _executeResponses = executeResponses;

  final List<NativeHttpClientConfigDto> createClientConfigs =
      <NativeHttpClientConfigDto>[];
  final List<_ExecuteCall> executeCalls = <_ExecuteCall>[];
  final List<int> closedClientIds = <int>[];
  final List<TransportResponse> _executeResponses;
  int disposeCount = 0;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    createClientConfigs.add(config);
    return 41;
  }

  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) async {
    executeCalls.add(_ExecuteCall(clientId: clientId, request: request));
    return _executeResponses[executeCalls.length - 1];
  }

  @override
  void closeClient(int clientId) {
    closedClientIds.add(clientId);
  }

  @override
  void dispose() {
    disposeCount += 1;
  }
}

final class _ExecuteCall {
  const _ExecuteCall({required this.clientId, required this.request});

  final int clientId;
  final NativeHttpRequestDto request;
}

Request _request(String url) {
  return RequestBuilder().url(Uri.parse(url)).get().build();
}
