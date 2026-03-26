import 'package:freezed_annotation/freezed_annotation.dart';

part 'rust_net_client_config.freezed.dart';

@freezed
class RustNetClientConfig with _$RustNetClientConfig {
  const RustNetClientConfig._();

  const factory RustNetClientConfig({
    Uri? baseUrl,
    @Default(<String, String>{}) Map<String, String> defaultHeaders,
    Duration? timeout,
    String? userAgent,
  }) = _RustNetClientConfig;
}
