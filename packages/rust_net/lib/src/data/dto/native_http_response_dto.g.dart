// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_http_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NativeHttpResponseDtoImpl _$$NativeHttpResponseDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$NativeHttpResponseDtoImpl(
      statusCode: (json['status_code'] as num).toInt(),
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
                k, (e as List<dynamic>).map((e) => e as String).toList()),
          ) ??
          const <String, List<String>>{},
      bodyBase64: json['body_base64'] as String,
      finalUrl: json['final_url'] as String?,
    );

Map<String, dynamic> _$$NativeHttpResponseDtoImplToJson(
        _$NativeHttpResponseDtoImpl instance) =>
    <String, dynamic>{
      'status_code': instance.statusCode,
      'headers': instance.headers,
      'body_base64': instance.bodyBase64,
      'final_url': instance.finalUrl,
    };
