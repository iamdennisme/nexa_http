// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'native_http_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NativeHttpResponseDto _$NativeHttpResponseDtoFromJson(
    Map<String, dynamic> json) {
  return _NativeHttpResponseDto.fromJson(json);
}

/// @nodoc
mixin _$NativeHttpResponseDto {
  @JsonKey(name: 'status_code')
  int get statusCode => throw _privateConstructorUsedError;
  Map<String, List<String>> get headers => throw _privateConstructorUsedError;
  @JsonKey(name: 'body_base64')
  String get bodyBase64 => throw _privateConstructorUsedError;
  @JsonKey(name: 'final_url')
  String? get finalUrl => throw _privateConstructorUsedError;

  /// Serializes this NativeHttpResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NativeHttpResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NativeHttpResponseDtoCopyWith<NativeHttpResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NativeHttpResponseDtoCopyWith<$Res> {
  factory $NativeHttpResponseDtoCopyWith(NativeHttpResponseDto value,
          $Res Function(NativeHttpResponseDto) then) =
      _$NativeHttpResponseDtoCopyWithImpl<$Res, NativeHttpResponseDto>;
  @useResult
  $Res call(
      {@JsonKey(name: 'status_code') int statusCode,
      Map<String, List<String>> headers,
      @JsonKey(name: 'body_base64') String bodyBase64,
      @JsonKey(name: 'final_url') String? finalUrl});
}

/// @nodoc
class _$NativeHttpResponseDtoCopyWithImpl<$Res,
        $Val extends NativeHttpResponseDto>
    implements $NativeHttpResponseDtoCopyWith<$Res> {
  _$NativeHttpResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NativeHttpResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statusCode = null,
    Object? headers = null,
    Object? bodyBase64 = null,
    Object? finalUrl = freezed,
  }) {
    return _then(_value.copyWith(
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int,
      headers: null == headers
          ? _value.headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      bodyBase64: null == bodyBase64
          ? _value.bodyBase64
          : bodyBase64 // ignore: cast_nullable_to_non_nullable
              as String,
      finalUrl: freezed == finalUrl
          ? _value.finalUrl
          : finalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NativeHttpResponseDtoImplCopyWith<$Res>
    implements $NativeHttpResponseDtoCopyWith<$Res> {
  factory _$$NativeHttpResponseDtoImplCopyWith(
          _$NativeHttpResponseDtoImpl value,
          $Res Function(_$NativeHttpResponseDtoImpl) then) =
      __$$NativeHttpResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'status_code') int statusCode,
      Map<String, List<String>> headers,
      @JsonKey(name: 'body_base64') String bodyBase64,
      @JsonKey(name: 'final_url') String? finalUrl});
}

/// @nodoc
class __$$NativeHttpResponseDtoImplCopyWithImpl<$Res>
    extends _$NativeHttpResponseDtoCopyWithImpl<$Res,
        _$NativeHttpResponseDtoImpl>
    implements _$$NativeHttpResponseDtoImplCopyWith<$Res> {
  __$$NativeHttpResponseDtoImplCopyWithImpl(_$NativeHttpResponseDtoImpl _value,
      $Res Function(_$NativeHttpResponseDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of NativeHttpResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statusCode = null,
    Object? headers = null,
    Object? bodyBase64 = null,
    Object? finalUrl = freezed,
  }) {
    return _then(_$NativeHttpResponseDtoImpl(
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int,
      headers: null == headers
          ? _value._headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      bodyBase64: null == bodyBase64
          ? _value.bodyBase64
          : bodyBase64 // ignore: cast_nullable_to_non_nullable
              as String,
      finalUrl: freezed == finalUrl
          ? _value.finalUrl
          : finalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NativeHttpResponseDtoImpl implements _NativeHttpResponseDto {
  const _$NativeHttpResponseDtoImpl(
      {@JsonKey(name: 'status_code') required this.statusCode,
      final Map<String, List<String>> headers = const <String, List<String>>{},
      @JsonKey(name: 'body_base64') required this.bodyBase64,
      @JsonKey(name: 'final_url') this.finalUrl})
      : _headers = headers;

  factory _$NativeHttpResponseDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$NativeHttpResponseDtoImplFromJson(json);

  @override
  @JsonKey(name: 'status_code')
  final int statusCode;
  final Map<String, List<String>> _headers;
  @override
  @JsonKey()
  Map<String, List<String>> get headers {
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_headers);
  }

  @override
  @JsonKey(name: 'body_base64')
  final String bodyBase64;
  @override
  @JsonKey(name: 'final_url')
  final String? finalUrl;

  @override
  String toString() {
    return 'NativeHttpResponseDto(statusCode: $statusCode, headers: $headers, bodyBase64: $bodyBase64, finalUrl: $finalUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NativeHttpResponseDtoImpl &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            (identical(other.bodyBase64, bodyBase64) ||
                other.bodyBase64 == bodyBase64) &&
            (identical(other.finalUrl, finalUrl) ||
                other.finalUrl == finalUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, statusCode,
      const DeepCollectionEquality().hash(_headers), bodyBase64, finalUrl);

  /// Create a copy of NativeHttpResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NativeHttpResponseDtoImplCopyWith<_$NativeHttpResponseDtoImpl>
      get copyWith => __$$NativeHttpResponseDtoImplCopyWithImpl<
          _$NativeHttpResponseDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NativeHttpResponseDtoImplToJson(
      this,
    );
  }
}

abstract class _NativeHttpResponseDto implements NativeHttpResponseDto {
  const factory _NativeHttpResponseDto(
          {@JsonKey(name: 'status_code') required final int statusCode,
          final Map<String, List<String>> headers,
          @JsonKey(name: 'body_base64') required final String bodyBase64,
          @JsonKey(name: 'final_url') final String? finalUrl}) =
      _$NativeHttpResponseDtoImpl;

  factory _NativeHttpResponseDto.fromJson(Map<String, dynamic> json) =
      _$NativeHttpResponseDtoImpl.fromJson;

  @override
  @JsonKey(name: 'status_code')
  int get statusCode;
  @override
  Map<String, List<String>> get headers;
  @override
  @JsonKey(name: 'body_base64')
  String get bodyBase64;
  @override
  @JsonKey(name: 'final_url')
  String? get finalUrl;

  /// Create a copy of NativeHttpResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NativeHttpResponseDtoImplCopyWith<_$NativeHttpResponseDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
