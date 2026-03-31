import '../../api/headers.dart';
import '../../api/media_type.dart';
import '../../api/request.dart';
import '../../api/response.dart';
import '../../api/response_body.dart';
import '../../data/mappers/native_http_client_config_mapper.dart';
import '../../data/mappers/native_http_request_mapper.dart';
import '../../data/sources/nexa_http_native_data_source.dart';
import '../../internal/transport/transport_response.dart';
import '../../native_bridge/nexa_http_native_data_source_factory.dart';
import '../config/client_options.dart';
import 'nexa_http_engine.dart';

final class NexaHttpEngineManager implements NexaHttpEngine {
  NexaHttpEngineManager({
    NexaHttpNativeDataSourceFactory dataSourceFactory =
        const NexaHttpNativeDataSourceFactory(),
  }) : _dataSourceFactory = dataSourceFactory;

  static NexaHttpEngine _instance = NexaHttpEngineManager();

  static NexaHttpEngine get instance => _instance;

  static void installForTesting(NexaHttpEngine engine) {
    _instance = engine;
  }

  static void resetForTesting() {
    _instance = NexaHttpEngineManager();
  }

  final NexaHttpNativeDataSourceFactory _dataSourceFactory;
  NexaHttpNativeDataSource? _dataSource;
  final Map<ClientOptions, Future<int>> _leaseFutures =
      <ClientOptions, Future<int>>{};

  @override
  Future<Response> execute({
    required ClientOptions clientConfig,
    required Request request,
  }) async {
    final leaseId = await _leaseFutures.putIfAbsent(
      clientConfig,
      () => _openLease(clientConfig),
    );
    final requestDto = NativeHttpRequestMapper.toDto(
      clientConfig: clientConfig,
      request: request,
    );
    final response = await _ensureDataSource().execute(leaseId, requestDto);
    return _decodeResponse(request, response);
  }

  Future<int> _openLease(ClientOptions clientConfig) async {
    try {
      return _ensureDataSource().createClient(
        NativeHttpClientConfigMapper.toDto(clientConfig),
      );
    } catch (error) {
      _leaseFutures.remove(clientConfig);
      rethrow;
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
      body: adoptResponseBodyBytes(
        payload.bodyBytes,
        contentType: contentType,
      ),
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
}
