import 'package:freezed_annotation/freezed_annotation.dart';

part 'native_http_error_dto.freezed.dart';
part 'native_http_error_dto.g.dart';

@freezed
class NativeHttpErrorDto with _$NativeHttpErrorDto {
  const factory NativeHttpErrorDto({
    required String code,
    required String message,
    @JsonKey(name: 'status_code') int? statusCode,
    @JsonKey(name: 'is_timeout') @Default(false) bool isTimeout,
    String? uri,
    Map<String, dynamic>? details,
  }) = _NativeHttpErrorDto;

  factory NativeHttpErrorDto.fromJson(Map<String, dynamic> json) =>
      _$NativeHttpErrorDtoFromJson(json);
}
