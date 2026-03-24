import 'data/mappers/native_http_client_config_mapper.dart';
import 'data/mappers/native_http_request_mapper.dart';
import 'data/sources/ffi_rust_net_native_data_source.dart';
import 'data/sources/rust_net_native_data_source.dart';
import 'package:rust_net_core/rust_net_core.dart';

class RustNetClient implements HttpExecutor {
  RustNetClient({
    this.config = const RustNetClientConfig(),
    RustNetNativeDataSource? dataSource,
  }) : _dataSource = dataSource ?? FfiRustNetNativeDataSource() {
    _clientId = _dataSource.createClient(
      NativeHttpClientConfigMapper.toDto(config),
    );
  }

  final RustNetClientConfig config;
  final RustNetNativeDataSource _dataSource;
  late final int _clientId;
  bool _isClosed = false;

  @override
  Future<RustNetResponse> execute(RustNetRequest request) async {
    _ensureOpen();

    return _dataSource.execute(
      _clientId,
      NativeHttpRequestMapper.toDto(
        clientConfig: config,
        request: request,
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _dataSource.closeClient(_clientId);
    _isClosed = true;
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('RustNetClient has already been closed.');
    }
  }
}
