// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_http_client_config_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NativeHttpClientConfigDtoImpl _$$NativeHttpClientConfigDtoImplFromJson(
  Map<String, dynamic> json,
) => _$NativeHttpClientConfigDtoImpl(
  baseUrl: json['base_url'] as String?,
  defaultHeaders:
      (json['default_headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  timeoutMs: (json['timeout_ms'] as num?)?.toInt(),
  userAgent: json['user_agent'] as String?,
);

Map<String, dynamic> _$$NativeHttpClientConfigDtoImplToJson(
  _$NativeHttpClientConfigDtoImpl instance,
) => <String, dynamic>{
  'base_url': instance.baseUrl,
  'default_headers': instance.defaultHeaders,
  'timeout_ms': instance.timeoutMs,
  'user_agent': instance.userAgent,
};
