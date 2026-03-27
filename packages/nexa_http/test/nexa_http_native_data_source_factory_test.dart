import 'dart:ffi';

import 'package:nexa_http/src/api/nexa_http_response.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';
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

    final dataSource = factory.create(libraryPath: '/tmp/libnexa_http_native.so');

    expect(dataSource, isA<_FakeNexaHttpNativeDataSource>());
    expect(resolvedExplicitPath, '/tmp/libnexa_http_native.so');
    expect((dataSource as _FakeNexaHttpNativeDataSource).library, same(loadedLibrary));
  });

  test('uses the default loader when no explicit library path is provided', () {
    var loadCallCount = 0;
    late final DynamicLibrary loadedLibrary;
    final factory = NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) {
        loadCallCount += 1;
        expect(explicitPath, isNull);
        loadedLibrary = DynamicLibrary.process();
        return loadedLibrary;
      },
      createDataSource: _FakeNexaHttpNativeDataSource.new,
    );

    final dataSource = factory.create();

    expect(loadCallCount, 1);
    expect(dataSource, isA<NexaHttpNativeDataSource>());
    expect((dataSource as _FakeNexaHttpNativeDataSource).library, same(loadedLibrary));
  });
}

final class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  _FakeNexaHttpNativeDataSource(this.library);

  final DynamicLibrary library;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<NexaHttpResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    throw UnimplementedError();
  }
}
