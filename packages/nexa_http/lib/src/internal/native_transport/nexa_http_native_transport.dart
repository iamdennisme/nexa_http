import '../../api/request.dart';
import '../../api/response.dart';
import '../config/client_options.dart';
import '../errors/nexa_http_failures.dart';
import 'native_http_client_config_mapper.dart';
import 'native_http_request_mapper.dart';
import 'nexa_http_native_data_source.dart';
import 'nexa_http_native_data_source_factory.dart';
import 'nexa_http_response_mapper.dart';
import 'nexa_http_testing_overrides.dart';

final class NexaHttpNativeTransport {
  NexaHttpNativeTransport({
    required ClientOptions options,
    NexaHttpNativeDataSourceFactory? dataSourceFactory,
    NexaHttpResponseMapper responseMapper = const NexaHttpResponseMapper(),
  }) : _options = options,
       _dataSourceFactory =
           dataSourceFactory ??
           NexaHttpTestingOverrides.nativeDataSourceFactory ??
           const NexaHttpNativeDataSourceFactory(),
       _responseMapper = responseMapper;

  final ClientOptions _options;
  final NexaHttpNativeDataSourceFactory _dataSourceFactory;
  final NexaHttpResponseMapper _responseMapper;

  NexaHttpNativeDataSource? _dataSource;
  Future<int>? _leaseFuture;
  Future<void>? _closeFuture;
  bool _isClosed = false;

  Future<Response> execute(
    Request request, {
    void Function(CancelNativeRequest cancelRequest)? onCancelReady,
    bool Function()? isCanceled,
  }) async {
    _throwIfCanceled(request, isCanceled);
    final leaseId = await _ensureLease();
    _throwIfCanceled(request, isCanceled);
    final requestDto = NativeHttpRequestMapper.toDto(
      clientConfig: _options,
      request: request,
    );
    final response = await _ensureDataSource().execute(
      leaseId,
      requestDto,
      onCancelReady: onCancelReady,
    );
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
      return _ensureDataSource().createClient(
        NativeHttpClientConfigMapper.toDto(_options),
      );
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

  void _throwIfCanceled(Request request, bool Function()? isCanceled) {
    if (isCanceled?.call() != true) {
      return;
    }
    throw NexaHttpFailures.canceled(
      stage: 'transport_preflight',
      uri: request.url,
    );
  }
}
