import '../api/request.dart';
import '../api/response.dart';
import '../data/dto/native_http_client_config_dto.dart';
import '../data/dto/native_http_request_dto.dart';
import '../data/sources/nexa_http_native_data_source.dart';
import '../internal/config/client_options.dart';
import '../native_bridge/nexa_http_native_data_source_factory.dart';
import 'nexa_http_response_mapper.dart';

typedef NexaHttpRequestMapper =
    NativeHttpRequestDto Function({
      required ClientOptions clientConfig,
      required Request request,
    });
typedef NexaHttpClientConfigMapper =
    NativeHttpClientConfigDto Function(ClientOptions config);

final class NexaHttpTransportSession {
  NexaHttpTransportSession({
    required ClientOptions options,
    required NexaHttpNativeDataSourceFactory dataSourceFactory,
    required NexaHttpRequestMapper requestMapper,
    required NexaHttpClientConfigMapper configMapper,
    required NexaHttpResponseMapper responseMapper,
  }) : _options = options,
       _dataSourceFactory = dataSourceFactory,
       _requestMapper = requestMapper,
       _configMapper = configMapper,
       _responseMapper = responseMapper;

  final ClientOptions _options;
  final NexaHttpNativeDataSourceFactory _dataSourceFactory;
  final NexaHttpRequestMapper _requestMapper;
  final NexaHttpClientConfigMapper _configMapper;
  final NexaHttpResponseMapper _responseMapper;

  NexaHttpNativeDataSource? _dataSource;
  Future<int>? _leaseFuture;
  Future<void>? _closeFuture;
  bool _isClosed = false;

  Future<Response> execute(Request request) async {
    final leaseId = await _ensureLease();
    final requestDto = _requestMapper(
      clientConfig: _options,
      request: request,
    );
    final response = await _ensureDataSource().execute(leaseId, requestDto);
    return _responseMapper.map(request: request, payload: response);
  }

  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }

    final closeFuture = _closeInternal();
    _closeFuture = closeFuture;
    return closeFuture;
  }

  Future<int> _ensureLease() {
    if (_isClosed) {
      throw StateError('This NexaHttpClient has already been closed.');
    }

    final existing = _leaseFuture;
    if (existing != null) {
      return existing;
    }

    final leaseFuture = _openLease();
    _leaseFuture = leaseFuture;
    return leaseFuture;
  }

  Future<int> _openLease() async {
    try {
      return _ensureDataSource().createClient(_configMapper(_options));
    } catch (error) {
      _leaseFuture = null;
      rethrow;
    }
  }

  Future<void> _closeInternal() async {
    _isClosed = true;

    final leaseFuture = _leaseFuture;
    try {
      if (leaseFuture != null) {
        final leaseId = await leaseFuture;
        _ensureDataSource().closeClient(leaseId);
      }
    } catch (_) {
      // If lazy initialization failed, there is no native lease to release.
    } finally {
      _dataSource?.dispose();
    }
  }

  NexaHttpNativeDataSource _ensureDataSource() {
    return _dataSource ??= _dataSourceFactory.create();
  }
}
