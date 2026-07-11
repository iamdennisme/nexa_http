import '../../api/nexa_http_exception.dart';
import '../../internal/errors/nexa_http_failures.dart';
import '../dto/native_http_error_dto.dart';

final class NativeHttpErrorMapper {
  const NativeHttpErrorMapper._();

  static NexaHttpException toDomain(NativeHttpErrorDto dto) {
    final details = dto.details?.cast<String, Object?>();
    final innerCode = details?['native_code'];
    final effectiveCode = innerCode is String ? innerCode : dto.code;
    final diagnostics = <String, Object?>{
      if (innerCode is String) 'native_envelope_code': dto.code,
      'native_code': effectiveCode,
      if (dto.statusCode != null) 'native_status_code': dto.statusCode,
      if (dto.isTimeout) 'native_is_timeout': true,
      ...?details,
    };
    final Uri? uri;
    try {
      uri = dto.uri == null ? null : Uri.parse(dto.uri!);
    } on FormatException catch (error) {
      return NexaHttpFailures.internal(
        message: 'The nexa_http native library returned an invalid error URI.',
        stage: 'native_error_uri_decode',
        error: error,
        diagnostics: diagnostics,
      );
    }

    return NexaHttpException(
      kind: _mapKind(code: effectiveCode, isTimeout: dto.isTimeout),
      message: dto.message,
      uri: uri,
      diagnostics: diagnostics,
    );
  }

  static NexaHttpFailureKind _mapKind({
    required String code,
    required bool isTimeout,
  }) {
    if (isTimeout || code == 'timeout') {
      return NexaHttpFailureKind.timeout;
    }

    return switch (code) {
      'canceled' => NexaHttpFailureKind.canceled,
      'network' => NexaHttpFailureKind.network,
      'invalid_request' => NexaHttpFailureKind.invalidRequest,
      'invalid_config' || 'invalid_proxy' => NexaHttpFailureKind.configuration,
      _ => NexaHttpFailureKind.internal,
    };
  }
}
