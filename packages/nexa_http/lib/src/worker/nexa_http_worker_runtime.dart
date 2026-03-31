import '../api/nexa_http_exception.dart';
import '../data/dto/native_http_client_config_dto.dart';
import '../data/dto/native_http_request_dto.dart';
import '../data/sources/nexa_http_native_data_source.dart';
import '../native_bridge/nexa_http_native_data_source_factory.dart';
import 'nexa_http_worker_protocol.dart';

final class NexaHttpWorkerRuntime {
  NexaHttpWorkerRuntime({
    NexaHttpNativeDataSourceFactory dataSourceFactory =
        const NexaHttpNativeDataSourceFactory(),
  }) : _dataSourceFactory = dataSourceFactory;

  final NexaHttpNativeDataSourceFactory _dataSourceFactory;
  NexaHttpNativeDataSource? _dataSource;

  NexaHttpWorkerResponse handle(NexaHttpWorkerRequest request) {
    try {
      switch (request) {
        case NexaHttpWarmUpWorkerRequest():
          _ensureDataSource();
          return NexaHttpWorkerSuccessResponse(
            requestId: request.requestId,
            result: const <String, Object?>{'state': 'ready'},
          );
        case NexaHttpShutdownWorkerRequest():
          return NexaHttpWorkerSuccessResponse(
            requestId: request.requestId,
            result: const <String, Object?>{'state': 'shutdown'},
          );
        case NexaHttpOpenClientWorkerRequest():
          final dataSource = _ensureDataSource();
          final clientId = dataSource.createClient(
            NativeHttpClientConfigDto.fromJson(
              request.config.cast<String, dynamic>(),
            ),
          );
          return NexaHttpWorkerSuccessResponse(
            requestId: request.requestId,
            result: <String, Object?>{'leaseId': clientId},
          );
        case NexaHttpExecuteWorkerRequest():
          return _execute(request);
        case NexaHttpCloseLeaseWorkerRequest():
          _ensureDataSource().closeClient(request.leaseId);
          return NexaHttpWorkerSuccessResponse(
            requestId: request.requestId,
            result: const <String, Object?>{'closed': true},
          );
      }
    } on NexaHttpException catch (error) {
      return NexaHttpWorkerErrorResponse(
        requestId: request.requestId,
        error: _encodeException(error),
      );
    } on Object catch (error) {
      return NexaHttpWorkerErrorResponse(
        requestId: request.requestId,
        error: <String, Object?>{
          'code': 'worker_runtime_error',
          'message': error.toString(),
          'is_timeout': false,
        },
      );
    }
  }

  NexaHttpNativeDataSource _ensureDataSource() {
    return _dataSource ??= _dataSourceFactory.create();
  }

  NexaHttpWorkerResponse _execute(NexaHttpExecuteWorkerRequest request) {
    throw UnsupportedError(
      'Async execute must be handled through handleAsync(request).',
    );
  }

  Future<NexaHttpWorkerResponse> handleAsync(NexaHttpWorkerRequest request) async {
    if (request case NexaHttpExecuteWorkerRequest()) {
      try {
        final response = await _ensureDataSource().execute(
          request.leaseId,
          _decodeRequest(request.request),
        );
        return NexaHttpWorkerSuccessResponse(
          requestId: request.requestId,
          result: <String, Object?>{
            'statusCode': response.statusCode,
            'headers': response.headers,
            'bodyBytes': response.bodyBytes,
            'finalUri': response.finalUri?.toString(),
          },
        );
      } on NexaHttpException catch (error) {
        return NexaHttpWorkerErrorResponse(
          requestId: request.requestId,
          error: _encodeException(error),
        );
      } on Object catch (error) {
        return NexaHttpWorkerErrorResponse(
          requestId: request.requestId,
          error: <String, Object?>{
            'code': 'worker_runtime_error',
            'message': error.toString(),
            'is_timeout': false,
          },
        );
      }
    }

    return Future<NexaHttpWorkerResponse>.value(handle(request));
  }


  NativeHttpRequestDto _decodeRequest(Map<String, Object?> payload) {
    final json = Map<String, dynamic>.from(payload);
    final bodyBytes = payload['bodyBytes'];
    return NativeHttpRequestDto.fromJson(json).copyWith(
      bodyBytes: bodyBytes is List ? bodyBytes.map((item) => item as int).toList() : null,
    );
  }

  Map<String, Object?> _encodeException(NexaHttpException error) {
    return <String, Object?>{
      'code': error.code,
      'message': error.message,
      'status_code': error.statusCode,
      'is_timeout': error.isTimeout,
      'uri': error.uri?.toString(),
      'details': error.details,
    };
  }
}
