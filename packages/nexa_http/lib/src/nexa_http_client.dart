import 'api/api.dart';
import 'data/mappers/native_http_client_config_mapper.dart';
import 'data/mappers/native_http_request_mapper.dart';
import 'data/sources/nexa_http_native_data_source.dart';
import 'native_bridge/nexa_http_native_data_source_factory.dart';

class NexaHttpClient implements HttpExecutor {
  NexaHttpClient({
    this.config = const NexaHttpClientConfig(),
    NexaHttpNativeDataSource? dataSource,
    String? libraryPath,
    String? nativeLibraryPath,
    NexaHttpNativeDataSourceFactory dataSourceFactory =
        const NexaHttpNativeDataSourceFactory(),
  }) : _dataSource =
           dataSource ??
           dataSourceFactory.create(
             libraryPath: libraryPath ?? nativeLibraryPath,
           ) {
    _clientId = _dataSource.createClient(
      NativeHttpClientConfigMapper.toDto(config),
    );
  }

  final NexaHttpClientConfig config;
  final NexaHttpNativeDataSource _dataSource;
  late final int _clientId;
  bool _isClosed = false;

  @override
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request) async {
    _ensureOpen();

    return _dataSource.execute(
      _clientId,
      NativeHttpRequestMapper.toDto(clientConfig: config, request: request),
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
      throw StateError('NexaHttpClient has already been closed.');
    }
  }
}
