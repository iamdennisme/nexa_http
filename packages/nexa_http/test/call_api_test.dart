import 'dart:async';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/testing/nexa_http_testing_overrides.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';
import 'package:test/test.dart';

import 'support/fake_native_bindings.dart';

void main() {
  tearDown(() {
    NexaHttpTestingOverrides.reset();
  });

  test(
    'cancel before execute completes canceled and consumes the call',
    () async {
      final client = NexaHttpClient();
      final call = client.newCall(
        RequestBuilder()
            .url(Uri.parse('https://example.com/cancel'))
            .get()
            .build(),
      );

      call.cancel();

      expect(call.isCanceled, isTrue);
      await expectLater(
        call.execute(),
        throwsA(
          isA<NexaHttpException>().having(
            (error) => error.kind,
            'kind',
            NexaHttpFailureKind.canceled,
          ),
        ),
      );
      await expectLater(call.execute(), throwsA(isA<StateError>()));
    },
  );

  test('execute is single-shot and newCall creates a fresh call', () async {
    final dataSource = _FakeNativeDataSource(
      executeResponses: const <TransportResponse>[
        TransportResponse(statusCode: 204),
        TransportResponse(statusCode: 204),
      ],
    );
    final dataSourceFactory = NexaHttpNativeDataSourceFactory(
      resolveBindings: FakeNativeBindings.new,
      createDataSource: (_) => dataSource,
    );
    NexaHttpTestingOverrides.installNativeDataSourceFactory(dataSourceFactory);
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

    final repeatedCall = client.newCall(request);
    final repeatedResponse = await repeatedCall.execute();
    expect(repeatedCall.request, same(request));
    expect(repeatedResponse.statusCode, 204);
    expect(dataSource.createClientConfigs, hasLength(1));
    expect(dataSource.executeCalls, hasLength(2));
    expect(
      dataSource.executeCalls[0].clientId,
      dataSource.executeCalls[1].clientId,
    );
  });

  test(
    'cancel after dispatch forwards cancellation into the active request',
    () async {
      final dataSource = _CancelableNativeDataSource();
      final dataSourceFactory = NexaHttpNativeDataSourceFactory(
        resolveBindings: FakeNativeBindings.new,
        createDataSource: (_) => dataSource,
      );
      NexaHttpTestingOverrides.installNativeDataSourceFactory(
        dataSourceFactory,
      );
      final client = NexaHttpClient();
      final call = client.newCall(
        RequestBuilder()
            .url(Uri.parse('https://example.com/cancel-in-flight'))
            .get()
            .build(),
      );

      final future = call.execute();
      await Future<void>.delayed(Duration.zero);
      call.cancel();
      call.cancel();

      await expectLater(
        future,
        throwsA(
          isA<NexaHttpException>().having(
            (error) => error.kind,
            'kind',
            NexaHttpFailureKind.canceled,
          ),
        ),
      );
      expect(call.isCanceled, isTrue);
      expect(dataSource.cancelReadyCount, 1);
      expect(dataSource.cancelInvocationCount, 1);
    },
  );

  test('callback-committed response wins over later cancellation', () async {
    final dataSource = _CallbackCommittedNativeDataSource();
    final dataSourceFactory = NexaHttpNativeDataSourceFactory(
      resolveBindings: FakeNativeBindings.new,
      createDataSource: (_) => dataSource,
    );
    NexaHttpTestingOverrides.installNativeDataSourceFactory(dataSourceFactory);
    final client = NexaHttpClient();
    final call = client.newCall(
      RequestBuilder()
          .url(Uri.parse('https://example.com/response-wins'))
          .get()
          .build(),
    );

    final responseFuture = call.execute();
    await Future<void>.delayed(Duration.zero);
    call.cancel();
    dataSource.complete(const TransportResponse(statusCode: 204));

    final response = await responseFuture;
    expect(response.statusCode, 204);
    expect(call.isCanceled, isTrue);
    expect(dataSource.cancelInvocationCount, 1);
  });

  test('cancel after completion does not forward cancellation again', () async {
    final dataSource = _CompletedCancelableNativeDataSource();
    final dataSourceFactory = NexaHttpNativeDataSourceFactory(
      resolveBindings: FakeNativeBindings.new,
      createDataSource: (_) => dataSource,
    );
    NexaHttpTestingOverrides.installNativeDataSourceFactory(dataSourceFactory);
    final client = NexaHttpClient();
    final call = client.newCall(
      RequestBuilder()
          .url(Uri.parse('https://example.com/already-done'))
          .get()
          .build(),
    );

    final response = await call.execute();
    expect(response.statusCode, 204);

    call.cancel();

    expect(call.isCanceled, isTrue);
    expect(dataSource.cancelReadyCount, 1);
    expect(dataSource.cancelInvocationCount, 0);
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
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) async {
    executeCalls.add(_ExecuteCall(clientId: clientId, request: request));
    return _executeResponses[executeCalls.length - 1];
  }

  @override
  void closeClient(int clientId) {}

  @override
  void dispose() {}
}

final class _ExecuteCall {
  const _ExecuteCall({required this.clientId, required this.request});

  final int clientId;
  final NativeHttpRequestDto request;
}

final class _CancelableNativeDataSource implements NexaHttpNativeDataSource {
  int cancelReadyCount = 0;
  int cancelInvocationCount = 0;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 101;

  @override
  void dispose() {}

  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) {
    final completer = Completer<TransportResponse>();
    onCancelReady?.call(() {
      cancelInvocationCount += 1;
      completer.completeError(
        NexaHttpException(
          kind: NexaHttpFailureKind.canceled,
          message: 'The request was canceled.',
          uri: Uri.parse(request.url),
        ),
      );
    });
    cancelReadyCount += 1;
    return completer.future;
  }
}

final class _CompletedCancelableNativeDataSource
    implements NexaHttpNativeDataSource {
  int cancelReadyCount = 0;
  int cancelInvocationCount = 0;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 102;

  @override
  void dispose() {}

  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) async {
    onCancelReady?.call(() {
      cancelInvocationCount += 1;
    });
    cancelReadyCount += 1;
    return const TransportResponse(statusCode: 204);
  }
}

final class _CallbackCommittedNativeDataSource
    implements NexaHttpNativeDataSource {
  final Completer<TransportResponse> _completer =
      Completer<TransportResponse>();
  int cancelInvocationCount = 0;

  void complete(TransportResponse response) {
    _completer.complete(response);
  }

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 103;

  @override
  void dispose() {}

  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) {
    onCancelReady?.call(() {
      cancelInvocationCount += 1;
    });
    return _completer.future;
  }
}
