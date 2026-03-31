import '../../internal/config/client_options.dart';
import '../dto/native_http_client_config_dto.dart';

final class NativeHttpClientConfigMapper {
  const NativeHttpClientConfigMapper._();

  static NativeHttpClientConfigDto toDto(ClientOptions config) {
    return NativeHttpClientConfigDto(
      baseUrl: config.baseUrl?.toString(),
      defaultHeaders: config.defaultHeaders,
      timeoutMs: config.timeout?.inMilliseconds,
      userAgent: config.userAgent,
    );
  }
}
