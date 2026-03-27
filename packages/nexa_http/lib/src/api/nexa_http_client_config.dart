import 'package:freezed_annotation/freezed_annotation.dart';

part 'nexa_http_client_config.freezed.dart';

@freezed
class NexaHttpClientConfig with _$NexaHttpClientConfig {
  const NexaHttpClientConfig._();

  const factory NexaHttpClientConfig({
    Uri? baseUrl,
    @Default(<String, String>{}) Map<String, String> defaultHeaders,
    Duration? timeout,
    String? userAgent,
  }) = _NexaHttpClientConfig;
}
