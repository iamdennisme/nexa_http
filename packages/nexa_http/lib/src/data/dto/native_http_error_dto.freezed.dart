// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'native_http_error_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NativeHttpErrorDto _$NativeHttpErrorDtoFromJson(Map<String, dynamic> json) {
  return _NativeHttpErrorDto.fromJson(json);
}

/// @nodoc
mixin _$NativeHttpErrorDto {
  String get code => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  @JsonKey(name: 'status_code')
  int? get statusCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_timeout')
  bool get isTimeout => throw _privateConstructorUsedError;
  String? get uri => throw _privateConstructorUsedError;
  Map<String, dynamic>? get details => throw _privateConstructorUsedError;

  /// Serializes this NativeHttpErrorDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NativeHttpErrorDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NativeHttpErrorDtoCopyWith<NativeHttpErrorDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NativeHttpErrorDtoCopyWith<$Res> {
  factory $NativeHttpErrorDtoCopyWith(
    NativeHttpErrorDto value,
    $Res Function(NativeHttpErrorDto) then,
  ) = _$NativeHttpErrorDtoCopyWithImpl<$Res, NativeHttpErrorDto>;
  @useResult
  $Res call({
    String code,
    String message,
    @JsonKey(name: 'status_code') int? statusCode,
    @JsonKey(name: 'is_timeout') bool isTimeout,
    String? uri,
    Map<String, dynamic>? details,
  });
}

/// @nodoc
class _$NativeHttpErrorDtoCopyWithImpl<$Res, $Val extends NativeHttpErrorDto>
    implements $NativeHttpErrorDtoCopyWith<$Res> {
  _$NativeHttpErrorDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NativeHttpErrorDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
    Object? statusCode = freezed,
    Object? isTimeout = null,
    Object? uri = freezed,
    Object? details = freezed,
  }) {
    return _then(
      _value.copyWith(
            code: null == code
                ? _value.code
                : code // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            statusCode: freezed == statusCode
                ? _value.statusCode
                : statusCode // ignore: cast_nullable_to_non_nullable
                      as int?,
            isTimeout: null == isTimeout
                ? _value.isTimeout
                : isTimeout // ignore: cast_nullable_to_non_nullable
                      as bool,
            uri: freezed == uri
                ? _value.uri
                : uri // ignore: cast_nullable_to_non_nullable
                      as String?,
            details: freezed == details
                ? _value.details
                : details // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NativeHttpErrorDtoImplCopyWith<$Res>
    implements $NativeHttpErrorDtoCopyWith<$Res> {
  factory _$$NativeHttpErrorDtoImplCopyWith(
    _$NativeHttpErrorDtoImpl value,
    $Res Function(_$NativeHttpErrorDtoImpl) then,
  ) = __$$NativeHttpErrorDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String code,
    String message,
    @JsonKey(name: 'status_code') int? statusCode,
    @JsonKey(name: 'is_timeout') bool isTimeout,
    String? uri,
    Map<String, dynamic>? details,
  });
}

/// @nodoc
class __$$NativeHttpErrorDtoImplCopyWithImpl<$Res>
    extends _$NativeHttpErrorDtoCopyWithImpl<$Res, _$NativeHttpErrorDtoImpl>
    implements _$$NativeHttpErrorDtoImplCopyWith<$Res> {
  __$$NativeHttpErrorDtoImplCopyWithImpl(
    _$NativeHttpErrorDtoImpl _value,
    $Res Function(_$NativeHttpErrorDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NativeHttpErrorDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
    Object? statusCode = freezed,
    Object? isTimeout = null,
    Object? uri = freezed,
    Object? details = freezed,
  }) {
    return _then(
      _$NativeHttpErrorDtoImpl(
        code: null == code
            ? _value.code
            : code // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        statusCode: freezed == statusCode
            ? _value.statusCode
            : statusCode // ignore: cast_nullable_to_non_nullable
                  as int?,
        isTimeout: null == isTimeout
            ? _value.isTimeout
            : isTimeout // ignore: cast_nullable_to_non_nullable
                  as bool,
        uri: freezed == uri
            ? _value.uri
            : uri // ignore: cast_nullable_to_non_nullable
                  as String?,
        details: freezed == details
            ? _value._details
            : details // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NativeHttpErrorDtoImpl implements _NativeHttpErrorDto {
  const _$NativeHttpErrorDtoImpl({
    required this.code,
    required this.message,
    @JsonKey(name: 'status_code') this.statusCode,
    @JsonKey(name: 'is_timeout') this.isTimeout = false,
    this.uri,
    final Map<String, dynamic>? details,
  }) : _details = details;

  factory _$NativeHttpErrorDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$NativeHttpErrorDtoImplFromJson(json);

  @override
  final String code;
  @override
  final String message;
  @override
  @JsonKey(name: 'status_code')
  final int? statusCode;
  @override
  @JsonKey(name: 'is_timeout')
  final bool isTimeout;
  @override
  final String? uri;
  final Map<String, dynamic>? _details;
  @override
  Map<String, dynamic>? get details {
    final value = _details;
    if (value == null) return null;
    if (_details is EqualUnmodifiableMapView) return _details;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'NativeHttpErrorDto(code: $code, message: $message, statusCode: $statusCode, isTimeout: $isTimeout, uri: $uri, details: $details)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NativeHttpErrorDtoImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            (identical(other.isTimeout, isTimeout) ||
                other.isTimeout == isTimeout) &&
            (identical(other.uri, uri) || other.uri == uri) &&
            const DeepCollectionEquality().equals(other._details, _details));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    code,
    message,
    statusCode,
    isTimeout,
    uri,
    const DeepCollectionEquality().hash(_details),
  );

  /// Create a copy of NativeHttpErrorDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NativeHttpErrorDtoImplCopyWith<_$NativeHttpErrorDtoImpl> get copyWith =>
      __$$NativeHttpErrorDtoImplCopyWithImpl<_$NativeHttpErrorDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NativeHttpErrorDtoImplToJson(this);
  }
}

abstract class _NativeHttpErrorDto implements NativeHttpErrorDto {
  const factory _NativeHttpErrorDto({
    required final String code,
    required final String message,
    @JsonKey(name: 'status_code') final int? statusCode,
    @JsonKey(name: 'is_timeout') final bool isTimeout,
    final String? uri,
    final Map<String, dynamic>? details,
  }) = _$NativeHttpErrorDtoImpl;

  factory _NativeHttpErrorDto.fromJson(Map<String, dynamic> json) =
      _$NativeHttpErrorDtoImpl.fromJson;

  @override
  String get code;
  @override
  String get message;
  @override
  @JsonKey(name: 'status_code')
  int? get statusCode;
  @override
  @JsonKey(name: 'is_timeout')
  bool get isTimeout;
  @override
  String? get uri;
  @override
  Map<String, dynamic>? get details;

  /// Create a copy of NativeHttpErrorDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NativeHttpErrorDtoImplCopyWith<_$NativeHttpErrorDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
