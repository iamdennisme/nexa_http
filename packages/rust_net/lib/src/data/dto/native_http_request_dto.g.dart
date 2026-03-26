// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_http_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NativeHttpRequestDtoImpl _$$NativeHttpRequestDtoImplFromJson(
  Map<String, dynamic> json,
) => _$NativeHttpRequestDtoImpl(
  method: json['method'] as String,
  url: json['url'] as String,
  headers:
      (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  timeoutMs: (json['timeout_ms'] as num?)?.toInt(),
);

Map<String, dynamic> _$$NativeHttpRequestDtoImplToJson(
  _$NativeHttpRequestDtoImpl instance,
) => <String, dynamic>{
  'method': instance.method,
  'url': instance.url,
  'headers': instance.headers,
  'timeout_ms': instance.timeoutMs,
};
