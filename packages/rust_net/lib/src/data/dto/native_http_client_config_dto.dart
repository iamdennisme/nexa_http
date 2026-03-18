import 'package:freezed_annotation/freezed_annotation.dart';

part 'native_http_client_config_dto.freezed.dart';
part 'native_http_client_config_dto.g.dart';

@freezed
class NativeHttpClientConfigDto with _$NativeHttpClientConfigDto {
  const factory NativeHttpClientConfigDto({
    @JsonKey(name: 'base_url') String? baseUrl,
    @JsonKey(name: 'default_headers')
    @Default(<String, String>{})
    Map<String, String> defaultHeaders,
    @JsonKey(name: 'timeout_ms') int? timeoutMs,
    @JsonKey(name: 'user_agent') String? userAgent,
  }) = _NativeHttpClientConfigDto;

  factory NativeHttpClientConfigDto.fromJson(Map<String, dynamic> json) =>
      _$NativeHttpClientConfigDtoFromJson(json);
}
