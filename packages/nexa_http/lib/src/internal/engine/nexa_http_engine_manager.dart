import '../../api/headers.dart';
import '../../api/media_type.dart';
import '../../api/request.dart';
import '../../api/response.dart';
import '../../api/response_body.dart';
import '../../data/dto/native_http_error_dto.dart';
import '../../data/mappers/native_http_client_config_mapper.dart';
import '../../data/mappers/native_http_error_mapper.dart';
import '../../data/mappers/native_http_request_mapper.dart';
import '../../worker/nexa_http_worker_protocol.dart';
import '../../worker/nexa_http_worker_proxy.dart';
import '../config/client_options.dart';
import 'nexa_http_engine.dart';

final class NexaHttpEngineManager implements NexaHttpEngine {
  NexaHttpEngineManager({
    NexaHttpWorkerProxyClient? workerProxy,
  }) : _workerProxy = workerProxy ?? NexaHttpWorkerProxy.shared;

  static NexaHttpEngine _instance = NexaHttpEngineManager();

  static NexaHttpEngine get instance => _instance;

  static void installForTesting(NexaHttpEngine engine) {
    _instance = engine;
  }

  static void resetForTesting() {
    _instance = NexaHttpEngineManager();
  }

  final NexaHttpWorkerProxyClient _workerProxy;
  final Map<ClientOptions, Future<int>> _leaseFutures =
      <ClientOptions, Future<int>>{};
  int _requestSequence = 0;

  @override
  Future<Response> execute({
    required ClientOptions clientConfig,
    required Request request,
  }) async {
    final leaseId = await _leaseFutures.putIfAbsent(
      clientConfig,
      () => _openLease(clientConfig),
    );
    final requestPayload = await NativeHttpRequestMapper.toPayload(
      clientConfig: clientConfig,
      request: request,
    );
    final response = await _workerProxy.send(
      NexaHttpExecuteWorkerRequest(
        requestId: _nextRequestId(),
        leaseId: leaseId,
        request: requestPayload,
      ),
    );
    final result = _requireSuccessResult(response);
    return _decodeResponse(request, result);
  }

  Future<int> _openLease(ClientOptions clientConfig) async {
    try {
      final response = await _workerProxy.send(
        NexaHttpOpenClientWorkerRequest(
          requestId: _nextRequestId(),
          config: NativeHttpClientConfigMapper.toDto(clientConfig).toJson(),
        ),
      );
      final result = _requireSuccessResult(response);
      final leaseId = result['leaseId'];
      if (leaseId is! int) {
        throw StateError('Worker open_client response is missing leaseId.');
      }
      return leaseId;
    } catch (error) {
      _leaseFutures.remove(clientConfig);
      rethrow;
    }
  }

  Response _decodeResponse(Request request, Map<String, Object?> payload) {
    final statusCode = payload['statusCode'];
    if (statusCode is! int) {
      throw StateError('Worker execute response is missing statusCode.');
    }

    final rawHeaders = payload['headers'];
    final headers = <String, List<String>>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          headers[key] = value.map((item) => item.toString()).toList();
        }
      }
    }

    final rawBodyBytes = payload['bodyBytes'];
    final bodyBytes = rawBodyBytes is List
        ? rawBodyBytes.map((item) => item as int).toList()
        : const <int>[];

    final finalUrlValue = payload['finalUri'];
    final finalUrl = finalUrlValue is String ? Uri.tryParse(finalUrlValue) : null;
    final responseRequest = finalUrl == null
        ? request
        : request.newBuilder().url(finalUrl).build();

    final contentType = _parseContentType(headers);

    return Response(
      request: responseRequest,
      statusCode: statusCode,
      headers: Headers.of(headers),
      body: ResponseBody.bytes(bodyBytes, contentType: contentType),
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

  Map<String, Object?> _requireSuccessResult(NexaHttpWorkerResponse response) {
    if (response case NexaHttpWorkerSuccessResponse(:final result)) {
      return result;
    }
    if (response case NexaHttpWorkerErrorResponse(:final error)) {
      throw NativeHttpErrorMapper.toDomain(
        NativeHttpErrorDto.fromJson(error.cast<String, dynamic>()),
      );
    }
    throw StateError('Unsupported worker response: $response');
  }

  int _nextRequestId() {
    _requestSequence += 1;
    return _requestSequence;
  }
}
