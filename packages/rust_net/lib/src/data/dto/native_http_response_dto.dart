import 'package:freezed_annotation/freezed_annotation.dart';

part 'native_http_response_dto.freezed.dart';
part 'native_http_response_dto.g.dart';

@freezed
class NativeHttpResponseDto with _$NativeHttpResponseDto {
  const factory NativeHttpResponseDto({
    @JsonKey(name: 'status_code') required int statusCode,
    @Default(<String, List<String>>{}) Map<String, List<String>> headers,
    @JsonKey(name: 'body_base64') required String bodyBase64,
    @JsonKey(name: 'final_url') String? finalUrl,
  }) = _NativeHttpResponseDto;

  factory NativeHttpResponseDto.fromJson(Map<String, dynamic> json) =>
      _$NativeHttpResponseDtoFromJson(json);
}
