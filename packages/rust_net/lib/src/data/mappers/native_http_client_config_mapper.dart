import 'package:rust_net_core/rust_net_core.dart';
import '../dto/native_http_client_config_dto.dart';

final class NativeHttpClientConfigMapper {
  const NativeHttpClientConfigMapper._();

  static NativeHttpClientConfigDto toDto(RustNetClientConfig config) {
    return NativeHttpClientConfigDto(
      baseUrl: config.baseUrl?.toString(),
      defaultHeaders: config.defaultHeaders,
      timeoutMs: config.timeout?.inMilliseconds,
      userAgent: config.userAgent,
    );
  }
}
