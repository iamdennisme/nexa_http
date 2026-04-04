import 'dart:ffi';

import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

void main() {
  test('passes the explicit library path to the dynamic library loader', () {
    late final DynamicLibrary loadedLibrary;
    String? resolvedExplicitPath;
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) {
        resolvedExplicitPath = explicitPath;
        loadedLibrary = DynamicLibrary.process();
        return loadedLibrary;
      },
      createDataSource: _FakeNexaHttpNativeDataSource.new,
    );

    final dataSource = factory.create(
      libraryPath: '/tmp/libnexa_http_native.so',
    );

    expect(dataSource, isA<_FakeNexaHttpNativeDataSource>());
    expect(resolvedExplicitPath, '/tmp/libnexa_http_native.so');
    expect(
      (dataSource as _FakeNexaHttpNativeDataSource).library,
      same(loadedLibrary),
    );
  });

  test('delegates to the registered runtime when no explicit path is provided', () {
    var runtimeOpenCount = 0;
    final runtimeLibrary = DynamicLibrary.process();
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) {
        expect(explicitPath, isNull);
        return loadNexaHttpDynamicLibraryForTesting(
          platform: NexaHttpHostPlatform.windows,
          openDynamicLibrary: (_) => throw StateError(
            'shared loader should not probe candidate paths',
          ),
          registeredRuntime: _FakeRuntime(() {
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

  test('surfaces a clear missing-runtime error when no runtime is registered', () {
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) {
        expect(explicitPath, isNull);
        return loadNexaHttpDynamicLibraryForTesting(
          platform: NexaHttpHostPlatform.macos,
          openDynamicLibrary: (_) =>
              throw StateError('should not open a native library path'),
        );
      },
      createDataSource: _FakeNexaHttpNativeDataSource.new,
    );

    expect(
      () => factory.create(),
      throwsA(
        predicate<Object>(
          (error) =>
              error is StateError &&
              error.toString().contains('nexa_http_native_macos'),
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
