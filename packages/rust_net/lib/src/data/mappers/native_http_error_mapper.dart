import '../../api/api.dart';
import '../dto/native_http_error_dto.dart';

final class NativeHttpErrorMapper {
  const NativeHttpErrorMapper._();

  static RustNetException toDomain(NativeHttpErrorDto dto) {
    return RustNetException(
      code: dto.code,
      message: dto.message,
      statusCode: dto.statusCode,
      isTimeout: dto.isTimeout,
      uri: dto.uri == null ? null : Uri.tryParse(dto.uri!),
      details: dto.details?.cast<String, Object?>(),
    );
  }
}
