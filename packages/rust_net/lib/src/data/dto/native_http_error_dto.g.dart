// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_http_error_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NativeHttpErrorDtoImpl _$$NativeHttpErrorDtoImplFromJson(
  Map<String, dynamic> json,
) => _$NativeHttpErrorDtoImpl(
  code: json['code'] as String,
  message: json['message'] as String,
  statusCode: (json['status_code'] as num?)?.toInt(),
  isTimeout: json['is_timeout'] as bool? ?? false,
  uri: json['uri'] as String?,
  details: json['details'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$NativeHttpErrorDtoImplToJson(
  _$NativeHttpErrorDtoImpl instance,
) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
  'status_code': instance.statusCode,
  'is_timeout': instance.isTimeout,
  'uri': instance.uri,
  'details': instance.details,
};
