import '../../api/nexa_http_exception.dart';
import '../dto/native_http_error_dto.dart';

final class NativeHttpErrorMapper {
  const NativeHttpErrorMapper._();

  static NexaHttpException toDomain(NativeHttpErrorDto dto) {
    return NexaHttpException(
      code: dto.code,
      message: dto.message,
      statusCode: dto.statusCode,
      isTimeout: dto.isTimeout,
      uri: dto.uri == null ? null : Uri.tryParse(dto.uri!),
      details: dto.details?.cast<String, Object?>(),
    );
  }
}
