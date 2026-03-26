import 'package:rust_net/src/api/rust_net_response.dart';
import 'package:rust_net/src/data/dto/native_http_client_config_dto.dart';
import 'package:rust_net/src/data/dto/native_http_request_dto.dart';
import 'package:rust_net/src/data/sources/rust_net_native_data_source.dart';
import 'package:rust_net/src/native_bridge/rust_net_native_data_source_factory.dart';
import 'package:test/test.dart';

void main() {
  test('uses the explicit library path when provided', () {
    final factory = RustNetNativeDataSourceFactory(
      resolveLibraryPath: ({String? explicitPath}) {
        throw StateError('resolver should not be called');
      },
      createDataSource: _FakeRustNetNativeDataSource.new,
    );

    final dataSource = factory.create(libraryPath: '/tmp/librust_net_native.so');

    expect(dataSource, isA<_FakeRustNetNativeDataSource>());
    expect((dataSource as _FakeRustNetNativeDataSource).libraryPath, '/tmp/librust_net_native.so');
  });

  test('falls back to the resolver when no explicit library path is provided', () {
    var resolveCallCount = 0;
    final factory = RustNetNativeDataSourceFactory(
      resolveLibraryPath: ({String? explicitPath}) {
        resolveCallCount += 1;
        expect(explicitPath, isNull);
        return 'librust_net_native.so';
      },
      createDataSource: _FakeRustNetNativeDataSource.new,
    );

    final dataSource = factory.create();

    expect(resolveCallCount, 1);
    expect(dataSource, isA<RustNetNativeDataSource>());
    expect((dataSource as _FakeRustNetNativeDataSource).libraryPath, 'librust_net_native.so');
  });
}

final class _FakeRustNetNativeDataSource implements RustNetNativeDataSource {
  _FakeRustNetNativeDataSource(this.libraryPath);

  final String libraryPath;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<RustNetResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    throw UnimplementedError();
  }
}
