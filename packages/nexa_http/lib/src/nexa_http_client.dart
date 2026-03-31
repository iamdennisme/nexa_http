import 'api/api.dart';
import 'client/real_call.dart';
import 'data/mappers/native_http_client_config_mapper.dart';
import 'data/mappers/native_http_request_mapper.dart';
import 'data/sources/nexa_http_native_data_source.dart';
import 'internal/config/client_options.dart';
import 'internal/testing/nexa_http_testing_overrides.dart';
import 'internal/transport/transport_response.dart';
import 'native_bridge/nexa_http_native_data_source_factory.dart';

final class NexaHttpClient {
  factory NexaHttpClient({
    Uri? baseUrl,
    Duration? callTimeout,
    Map<String, String> defaultHeaders = const <String, String>{},
    String? userAgent,
  }) {
    return NexaHttpClient._(
      ClientOptions(
        baseUrl: baseUrl,
        defaultHeaders: _normalizeDefaultHeaders(defaultHeaders),
        timeout: callTimeout,
        userAgent: userAgent,
      ),
    );
  }

  NexaHttpClient._(this._options)
    : _dataSourceFactory =
          NexaHttpTestingOverrides.nativeDataSourceFactory ??
          const NexaHttpNativeDataSourceFactory();

  final ClientOptions _options;
  final NexaHttpNativeDataSourceFactory _dataSourceFactory;
  NexaHttpNativeDataSource? _dataSource;
  Headers? _defaultHeadersView;
  Future<int>? _leaseFuture;
  Future<void>? _closeFuture;
  bool _isClosed = false;

  Uri? get baseUrl => _options.baseUrl;

  Duration? get callTimeout => _options.timeout;

  Headers get defaultHeaders =>
      _defaultHeadersView ??= Headers.fromMap(_options.defaultHeaders);

  String? get userAgent => _options.userAgent;

  Call newCall(Request request) {
    return RealCall(request: request, executeRequest: _execute);
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

  Future<Response> _execute(Request request) async {
    final leaseId = await _ensureLease();
    final requestDto = NativeHttpRequestMapper.toDto(
      clientConfig: _options,
      request: request,
    );
    final response = await _ensureDataSource().execute(leaseId, requestDto);
    return _decodeResponse(request, response);
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

  Response _decodeResponse(Request request, TransportResponse payload) {
    final finalUrl = payload.finalUri;
    final responseRequest = finalUrl == null
        ? request
        : request.newBuilder().url(finalUrl).build();

    final headers = payload.headers;
    final contentType = _parseContentType(headers);

    return Response(
      request: responseRequest,
      statusCode: payload.statusCode,
      headers: Headers.of(headers),
      body: adoptResponseBodyBytes(payload.bodyBytes, contentType: contentType),
      finalUrl: finalUrl,
    );
  }

  MediaType? _parseContentType(Map<String, List<String>> headers) {
    final values = headers['content-type'];
    if (values == null || values.isEmpty) {
      return null;
    }

    try {
      return MediaType.parse(values.last);
    } on FormatException {
      return null;
    }
  }

  static Map<String, String> _normalizeDefaultHeaders(
    Map<String, String> headers,
  ) {
    if (headers.isEmpty) {
      return const <String, String>{};
    }

    final normalized = <String, String>{};
    for (final entry in headers.entries) {
      normalized[entry.key.trim().toLowerCase()] = entry.value;
    }
    return Map<String, String>.unmodifiable(normalized);
  }
}
