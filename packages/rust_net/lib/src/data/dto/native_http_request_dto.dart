import 'package:freezed_annotation/freezed_annotation.dart';

part 'native_http_request_dto.freezed.dart';
part 'native_http_request_dto.g.dart';

@freezed
class NativeHttpRequestDto with _$NativeHttpRequestDto {
  const factory NativeHttpRequestDto({
    required String method,
    required String url,
    @Default(<String, String>{}) Map<String, String> headers,
    @JsonKey(name: 'body_base64') String? bodyBase64,
    @JsonKey(name: 'timeout_ms') int? timeoutMs,
  }) = _NativeHttpRequestDto;

  factory NativeHttpRequestDto.fromJson(Map<String, dynamic> json) =>
      _$NativeHttpRequestDtoFromJson(json);
}
