import 'dart:ffi';

import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

void main() {
  test('asks the loader for a library handle without exposing a path parameter', () {
    var loadCount = 0;
    late final DynamicLibrary loadedLibrary;
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: () {
        loadCount += 1;
        loadedLibrary = DynamicLibrary.process();
        return loadedLibrary;
      },
      createDataSource: _FakeNexaHttpNativeDataSource.new,
    );

    final dataSource = factory.create();

    expect(loadCount, 1);
    expect(dataSource, isA<_FakeNexaHttpNativeDataSource>());
    expect(
      (dataSource as _FakeNexaHttpNativeDataSource).library,
      same(loadedLibrary),
    );
  });

  test('delegates to the registered strategy by default', () {
    var runtimeOpenCount = 0;
    final runtimeLibrary = DynamicLibrary.process();
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: () {
        return loadNexaHttpDynamicLibraryForTesting(
          registeredStrategy: _FakeRuntime(() {
            runtimeOpenCount += 1;
            return runtimeLibrary;
          }),
        );
      },
      createDataSource: _FakeNexaHttpNativeDataSource.new,
    );

    final dataSource = factory.create();

    expect(runtimeOpenCount, 1);
    expect(
      (dataSource as _FakeNexaHttpNativeDataSource).library,
      same(runtimeLibrary),
    );
  });

  test('surfaces a clear missing-strategy error when nothing is registered', () {
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: () {
        return loadNexaHttpDynamicLibraryForTesting();
      },
      createDataSource: _FakeNexaHttpNativeDataSource.new,
    );

    expect(
      () => factory.create(),
      throwsA(
        predicate<Object>(
          (error) =>
              error is StateError &&
              error.toString().contains('Register a platform strategy first'),
        ),
      ),
    );
  });
}

final class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNexaHttpNativeDataSource(this.library);

  final DynamicLibrary library;

  @override
  void closeClient(int clientId) {}

  @override
  void dispose() {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<TransportResponse> execute(int clientId, NativeHttpRequestDto request,
      {RegisterCancelRequest? onCancelReady}) async {
    throw UnimplementedError();
  }
}

final class _FakeRuntime implements NexaHttpNativeRuntime {
  _FakeRuntime(this._open);

  final DynamicLibrary Function() _open;

  @override
  DynamicLibrary open() => _open();
}
