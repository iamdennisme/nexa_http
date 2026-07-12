import 'dart:ffi';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetNexaHttpNativeBindingsForTesting);

  test(
    'resolves bindings once and passes the same instance to the creator',
    () {
      var resolveCount = 0;
      final bindings = _FakeBindings();
      final factory = NexaHttpNativeDataSourceFactory(
        resolveBindings: () {
          resolveCount += 1;
          return bindings;
        },
        createDataSource: _FakeNexaHttpNativeDataSource.new,
      );

      final dataSource = factory.create() as _FakeNexaHttpNativeDataSource;

      expect(resolveCount, 1);
      expect(dataSource.bindings, same(bindings));
    },
  );

  test('normalizes missing carrier bindings to unavailable', () {
    const factory = NexaHttpNativeDataSourceFactory();

    expect(
      factory.create,
      throwsA(
        isA<NexaHttpException>()
            .having(
              (error) => error.kind,
              'kind',
              NexaHttpFailureKind.unavailable,
            )
            .having(
              (error) => error.diagnostics?['stage'],
              'stage',
              'native_bindings_create',
            )
            .having(
              (error) => error.diagnostics?['error'],
              'error',
              contains('plugin registration'),
            ),
      ),
    );
  });

  test('normalizes native binding construction failures to unavailable', () {
    final factory = NexaHttpNativeDataSourceFactory(
      resolveBindings: _FakeBindings.new,
      createDataSource: (_) => throw ArgumentError('missing native symbol'),
    );

    expect(
      factory.create,
      throwsA(
        isA<NexaHttpException>()
            .having(
              (error) => error.diagnostics?['stage'],
              'stage',
              'native_bindings_create',
            )
            .having(
              (error) => error.diagnostics?['error'],
              'error',
              contains('missing native symbol'),
            ),
      ),
    );
  });

  test('passes through an existing typed HTTP failure', () {
    final expected = NexaHttpException(
      kind: NexaHttpFailureKind.internal,
      message: 'already normalized',
    );
    final factory = NexaHttpNativeDataSourceFactory(
      resolveBindings: _FakeBindings.new,
      createDataSource: (_) => throw expected,
    );

    expect(factory.create, throwsA(same(expected)));
  });
}

final class _FakeBindings implements NexaHttpBindings {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Pointer<NativeFunction<Void Function(Pointer<NexaHttpBinaryResult>)>>
  get nexaHttpBinaryResultFreeAddress => nullptr;

  @override
  Pointer<NativeFunction<Void Function(Pointer<Char>)>>
  get nexaHttpStringFreeAddress => nullptr;
}

final class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNexaHttpNativeDataSource(this.bindings);

  final NexaHttpBindings bindings;

  @override
  void closeClient(int clientId) {}
  @override
  void dispose() {}
  @override
  int createClient(NativeHttpClientConfigDto config) => 1;
  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) async => throw UnimplementedError();
}
