import 'package:freezed_annotation/freezed_annotation.dart';

import 'native_http_error_dto.dart';
import 'native_http_response_dto.dart';

part 'native_http_result_dto.freezed.dart';
part 'native_http_result_dto.g.dart';

@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
class NativeHttpResultDto with _$NativeHttpResultDto {
  const factory NativeHttpResultDto.success({
    required NativeHttpResponseDto response,
  }) = NativeHttpResultSuccessDto;

  const factory NativeHttpResultDto.error({
    required NativeHttpErrorDto error,
  }) = NativeHttpResultErrorDto;

  factory NativeHttpResultDto.fromJson(Map<String, dynamic> json) =>
      _$NativeHttpResultDtoFromJson(json);
}
