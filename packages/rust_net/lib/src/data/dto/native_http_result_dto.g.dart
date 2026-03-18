// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_http_result_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NativeHttpResultSuccessDtoImpl _$$NativeHttpResultSuccessDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$NativeHttpResultSuccessDtoImpl(
      response: NativeHttpResponseDto.fromJson(
          json['response'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$NativeHttpResultSuccessDtoImplToJson(
        _$NativeHttpResultSuccessDtoImpl instance) =>
    <String, dynamic>{
      'response': instance.response,
      'type': instance.$type,
    };

_$NativeHttpResultErrorDtoImpl _$$NativeHttpResultErrorDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$NativeHttpResultErrorDtoImpl(
      error: NativeHttpErrorDto.fromJson(json['error'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$NativeHttpResultErrorDtoImplToJson(
        _$NativeHttpResultErrorDtoImpl instance) =>
    <String, dynamic>{
      'error': instance.error,
      'type': instance.$type,
    };
