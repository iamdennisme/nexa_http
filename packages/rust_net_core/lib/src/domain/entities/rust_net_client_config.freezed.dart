// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rust_net_client_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RustNetClientConfig {
  Uri? get baseUrl => throw _privateConstructorUsedError;
  Map<String, String> get defaultHeaders => throw _privateConstructorUsedError;
  Duration? get timeout => throw _privateConstructorUsedError;
  String? get userAgent => throw _privateConstructorUsedError;

  /// Create a copy of RustNetClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RustNetClientConfigCopyWith<RustNetClientConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RustNetClientConfigCopyWith<$Res> {
  factory $RustNetClientConfigCopyWith(
          RustNetClientConfig value, $Res Function(RustNetClientConfig) then) =
      _$RustNetClientConfigCopyWithImpl<$Res, RustNetClientConfig>;
  @useResult
  $Res call(
      {Uri? baseUrl,
      Map<String, String> defaultHeaders,
      Duration? timeout,
      String? userAgent});
}

/// @nodoc
class _$RustNetClientConfigCopyWithImpl<$Res, $Val extends RustNetClientConfig>
    implements $RustNetClientConfigCopyWith<$Res> {
  _$RustNetClientConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RustNetClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = freezed,
    Object? defaultHeaders = null,
    Object? timeout = freezed,
    Object? userAgent = freezed,
  }) {
    return _then(_value.copyWith(
      baseUrl: freezed == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as Uri?,
      defaultHeaders: null == defaultHeaders
          ? _value.defaultHeaders
          : defaultHeaders // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      timeout: freezed == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as Duration?,
      userAgent: freezed == userAgent
          ? _value.userAgent
          : userAgent // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RustNetClientConfigImplCopyWith<$Res>
    implements $RustNetClientConfigCopyWith<$Res> {
  factory _$$RustNetClientConfigImplCopyWith(_$RustNetClientConfigImpl value,
          $Res Function(_$RustNetClientConfigImpl) then) =
      __$$RustNetClientConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Uri? baseUrl,
      Map<String, String> defaultHeaders,
      Duration? timeout,
      String? userAgent});
}

/// @nodoc
class __$$RustNetClientConfigImplCopyWithImpl<$Res>
    extends _$RustNetClientConfigCopyWithImpl<$Res, _$RustNetClientConfigImpl>
    implements _$$RustNetClientConfigImplCopyWith<$Res> {
  __$$RustNetClientConfigImplCopyWithImpl(_$RustNetClientConfigImpl _value,
      $Res Function(_$RustNetClientConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of RustNetClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = freezed,
    Object? defaultHeaders = null,
    Object? timeout = freezed,
    Object? userAgent = freezed,
  }) {
    return _then(_$RustNetClientConfigImpl(
      baseUrl: freezed == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as Uri?,
      defaultHeaders: null == defaultHeaders
          ? _value._defaultHeaders
          : defaultHeaders // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      timeout: freezed == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as Duration?,
      userAgent: freezed == userAgent
          ? _value.userAgent
          : userAgent // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$RustNetClientConfigImpl extends _RustNetClientConfig {
  const _$RustNetClientConfigImpl(
      {this.baseUrl,
      final Map<String, String> defaultHeaders = const <String, String>{},
      this.timeout,
      this.userAgent})
      : _defaultHeaders = defaultHeaders,
        super._();

  @override
  final Uri? baseUrl;
  final Map<String, String> _defaultHeaders;
  @override
  @JsonKey()
  Map<String, String> get defaultHeaders {
    if (_defaultHeaders is EqualUnmodifiableMapView) return _defaultHeaders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_defaultHeaders);
  }

  @override
  final Duration? timeout;
  @override
  final String? userAgent;

  @override
  String toString() {
    return 'RustNetClientConfig(baseUrl: $baseUrl, defaultHeaders: $defaultHeaders, timeout: $timeout, userAgent: $userAgent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RustNetClientConfigImpl &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            const DeepCollectionEquality()
                .equals(other._defaultHeaders, _defaultHeaders) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.userAgent, userAgent) ||
                other.userAgent == userAgent));
  }

  @override
  int get hashCode => Object.hash(runtimeType, baseUrl,
      const DeepCollectionEquality().hash(_defaultHeaders), timeout, userAgent);

  /// Create a copy of RustNetClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RustNetClientConfigImplCopyWith<_$RustNetClientConfigImpl> get copyWith =>
      __$$RustNetClientConfigImplCopyWithImpl<_$RustNetClientConfigImpl>(
          this, _$identity);
}

abstract class _RustNetClientConfig extends RustNetClientConfig {
  const factory _RustNetClientConfig(
      {final Uri? baseUrl,
      final Map<String, String> defaultHeaders,
      final Duration? timeout,
      final String? userAgent}) = _$RustNetClientConfigImpl;
  const _RustNetClientConfig._() : super._();

  @override
  Uri? get baseUrl;
  @override
  Map<String, String> get defaultHeaders;
  @override
  Duration? get timeout;
  @override
  String? get userAgent;

  /// Create a copy of RustNetClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RustNetClientConfigImplCopyWith<_$RustNetClientConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
