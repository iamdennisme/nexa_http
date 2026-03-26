// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'native_http_client_config_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NativeHttpClientConfigDto _$NativeHttpClientConfigDtoFromJson(
  Map<String, dynamic> json,
) {
  return _NativeHttpClientConfigDto.fromJson(json);
}

/// @nodoc
mixin _$NativeHttpClientConfigDto {
  @JsonKey(name: 'base_url')
  String? get baseUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_headers')
  Map<String, String> get defaultHeaders => throw _privateConstructorUsedError;
  @JsonKey(name: 'timeout_ms')
  int? get timeoutMs => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_agent')
  String? get userAgent => throw _privateConstructorUsedError;

  /// Serializes this NativeHttpClientConfigDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NativeHttpClientConfigDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NativeHttpClientConfigDtoCopyWith<NativeHttpClientConfigDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NativeHttpClientConfigDtoCopyWith<$Res> {
  factory $NativeHttpClientConfigDtoCopyWith(
    NativeHttpClientConfigDto value,
    $Res Function(NativeHttpClientConfigDto) then,
  ) = _$NativeHttpClientConfigDtoCopyWithImpl<$Res, NativeHttpClientConfigDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'base_url') String? baseUrl,
    @JsonKey(name: 'default_headers') Map<String, String> defaultHeaders,
    @JsonKey(name: 'timeout_ms') int? timeoutMs,
    @JsonKey(name: 'user_agent') String? userAgent,
  });
}

/// @nodoc
class _$NativeHttpClientConfigDtoCopyWithImpl<
  $Res,
  $Val extends NativeHttpClientConfigDto
>
    implements $NativeHttpClientConfigDtoCopyWith<$Res> {
  _$NativeHttpClientConfigDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NativeHttpClientConfigDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = freezed,
    Object? defaultHeaders = null,
    Object? timeoutMs = freezed,
    Object? userAgent = freezed,
  }) {
    return _then(
      _value.copyWith(
            baseUrl:
                freezed == baseUrl
                    ? _value.baseUrl
                    : baseUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            defaultHeaders:
                null == defaultHeaders
                    ? _value.defaultHeaders
                    : defaultHeaders // ignore: cast_nullable_to_non_nullable
                        as Map<String, String>,
            timeoutMs:
                freezed == timeoutMs
                    ? _value.timeoutMs
                    : timeoutMs // ignore: cast_nullable_to_non_nullable
                        as int?,
            userAgent:
                freezed == userAgent
                    ? _value.userAgent
                    : userAgent // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NativeHttpClientConfigDtoImplCopyWith<$Res>
    implements $NativeHttpClientConfigDtoCopyWith<$Res> {
  factory _$$NativeHttpClientConfigDtoImplCopyWith(
    _$NativeHttpClientConfigDtoImpl value,
    $Res Function(_$NativeHttpClientConfigDtoImpl) then,
  ) = __$$NativeHttpClientConfigDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'base_url') String? baseUrl,
    @JsonKey(name: 'default_headers') Map<String, String> defaultHeaders,
    @JsonKey(name: 'timeout_ms') int? timeoutMs,
    @JsonKey(name: 'user_agent') String? userAgent,
  });
}

/// @nodoc
class __$$NativeHttpClientConfigDtoImplCopyWithImpl<$Res>
    extends
        _$NativeHttpClientConfigDtoCopyWithImpl<
          $Res,
          _$NativeHttpClientConfigDtoImpl
        >
    implements _$$NativeHttpClientConfigDtoImplCopyWith<$Res> {
  __$$NativeHttpClientConfigDtoImplCopyWithImpl(
    _$NativeHttpClientConfigDtoImpl _value,
    $Res Function(_$NativeHttpClientConfigDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NativeHttpClientConfigDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = freezed,
    Object? defaultHeaders = null,
    Object? timeoutMs = freezed,
    Object? userAgent = freezed,
  }) {
    return _then(
      _$NativeHttpClientConfigDtoImpl(
        baseUrl:
            freezed == baseUrl
                ? _value.baseUrl
                : baseUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        defaultHeaders:
            null == defaultHeaders
                ? _value._defaultHeaders
                : defaultHeaders // ignore: cast_nullable_to_non_nullable
                    as Map<String, String>,
        timeoutMs:
            freezed == timeoutMs
                ? _value.timeoutMs
                : timeoutMs // ignore: cast_nullable_to_non_nullable
                    as int?,
        userAgent:
            freezed == userAgent
                ? _value.userAgent
                : userAgent // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NativeHttpClientConfigDtoImpl implements _NativeHttpClientConfigDto {
  const _$NativeHttpClientConfigDtoImpl({
    @JsonKey(name: 'base_url') this.baseUrl,
    @JsonKey(name: 'default_headers')
    final Map<String, String> defaultHeaders = const <String, String>{},
    @JsonKey(name: 'timeout_ms') this.timeoutMs,
    @JsonKey(name: 'user_agent') this.userAgent,
  }) : _defaultHeaders = defaultHeaders;

  factory _$NativeHttpClientConfigDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$NativeHttpClientConfigDtoImplFromJson(json);

  @override
  @JsonKey(name: 'base_url')
  final String? baseUrl;
  final Map<String, String> _defaultHeaders;
  @override
  @JsonKey(name: 'default_headers')
  Map<String, String> get defaultHeaders {
    if (_defaultHeaders is EqualUnmodifiableMapView) return _defaultHeaders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_defaultHeaders);
  }

  @override
  @JsonKey(name: 'timeout_ms')
  final int? timeoutMs;
  @override
  @JsonKey(name: 'user_agent')
  final String? userAgent;

  @override
  String toString() {
    return 'NativeHttpClientConfigDto(baseUrl: $baseUrl, defaultHeaders: $defaultHeaders, timeoutMs: $timeoutMs, userAgent: $userAgent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NativeHttpClientConfigDtoImpl &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            const DeepCollectionEquality().equals(
              other._defaultHeaders,
              _defaultHeaders,
            ) &&
            (identical(other.timeoutMs, timeoutMs) ||
                other.timeoutMs == timeoutMs) &&
            (identical(other.userAgent, userAgent) ||
                other.userAgent == userAgent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    baseUrl,
    const DeepCollectionEquality().hash(_defaultHeaders),
    timeoutMs,
    userAgent,
  );

  /// Create a copy of NativeHttpClientConfigDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NativeHttpClientConfigDtoImplCopyWith<_$NativeHttpClientConfigDtoImpl>
  get copyWith => __$$NativeHttpClientConfigDtoImplCopyWithImpl<
    _$NativeHttpClientConfigDtoImpl
  >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NativeHttpClientConfigDtoImplToJson(this);
  }
}

abstract class _NativeHttpClientConfigDto implements NativeHttpClientConfigDto {
  const factory _NativeHttpClientConfigDto({
    @JsonKey(name: 'base_url') final String? baseUrl,
    @JsonKey(name: 'default_headers') final Map<String, String> defaultHeaders,
    @JsonKey(name: 'timeout_ms') final int? timeoutMs,
    @JsonKey(name: 'user_agent') final String? userAgent,
  }) = _$NativeHttpClientConfigDtoImpl;

  factory _NativeHttpClientConfigDto.fromJson(Map<String, dynamic> json) =
      _$NativeHttpClientConfigDtoImpl.fromJson;

  @override
  @JsonKey(name: 'base_url')
  String? get baseUrl;
  @override
  @JsonKey(name: 'default_headers')
  Map<String, String> get defaultHeaders;
  @override
  @JsonKey(name: 'timeout_ms')
  int? get timeoutMs;
  @override
  @JsonKey(name: 'user_agent')
  String? get userAgent;

  /// Create a copy of NativeHttpClientConfigDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NativeHttpClientConfigDtoImplCopyWith<_$NativeHttpClientConfigDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
