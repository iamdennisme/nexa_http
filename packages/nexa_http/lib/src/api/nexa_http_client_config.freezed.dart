// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nexa_http_client_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$NexaHttpClientConfig {
  Uri? get baseUrl => throw _privateConstructorUsedError;
  Map<String, String> get defaultHeaders => throw _privateConstructorUsedError;
  Duration? get timeout => throw _privateConstructorUsedError;
  String? get userAgent => throw _privateConstructorUsedError;

  /// Create a copy of NexaHttpClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NexaHttpClientConfigCopyWith<NexaHttpClientConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NexaHttpClientConfigCopyWith<$Res> {
  factory $NexaHttpClientConfigCopyWith(
    NexaHttpClientConfig value,
    $Res Function(NexaHttpClientConfig) then,
  ) = _$NexaHttpClientConfigCopyWithImpl<$Res, NexaHttpClientConfig>;
  @useResult
  $Res call({
    Uri? baseUrl,
    Map<String, String> defaultHeaders,
    Duration? timeout,
    String? userAgent,
  });
}

/// @nodoc
class _$NexaHttpClientConfigCopyWithImpl<
  $Res,
  $Val extends NexaHttpClientConfig
>
    implements $NexaHttpClientConfigCopyWith<$Res> {
  _$NexaHttpClientConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NexaHttpClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = freezed,
    Object? defaultHeaders = null,
    Object? timeout = freezed,
    Object? userAgent = freezed,
  }) {
    return _then(
      _value.copyWith(
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
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NexaHttpClientConfigImplCopyWith<$Res>
    implements $NexaHttpClientConfigCopyWith<$Res> {
  factory _$$NexaHttpClientConfigImplCopyWith(
    _$NexaHttpClientConfigImpl value,
    $Res Function(_$NexaHttpClientConfigImpl) then,
  ) = __$$NexaHttpClientConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Uri? baseUrl,
    Map<String, String> defaultHeaders,
    Duration? timeout,
    String? userAgent,
  });
}

/// @nodoc
class __$$NexaHttpClientConfigImplCopyWithImpl<$Res>
    extends _$NexaHttpClientConfigCopyWithImpl<$Res, _$NexaHttpClientConfigImpl>
    implements _$$NexaHttpClientConfigImplCopyWith<$Res> {
  __$$NexaHttpClientConfigImplCopyWithImpl(
    _$NexaHttpClientConfigImpl _value,
    $Res Function(_$NexaHttpClientConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NexaHttpClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = freezed,
    Object? defaultHeaders = null,
    Object? timeout = freezed,
    Object? userAgent = freezed,
  }) {
    return _then(
      _$NexaHttpClientConfigImpl(
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
      ),
    );
  }
}

/// @nodoc

class _$NexaHttpClientConfigImpl extends _NexaHttpClientConfig {
  const _$NexaHttpClientConfigImpl({
    this.baseUrl,
    final Map<String, String> defaultHeaders = const <String, String>{},
    this.timeout,
    this.userAgent,
  }) : _defaultHeaders = defaultHeaders,
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
    return 'NexaHttpClientConfig(baseUrl: $baseUrl, defaultHeaders: $defaultHeaders, timeout: $timeout, userAgent: $userAgent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NexaHttpClientConfigImpl &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            const DeepCollectionEquality().equals(
              other._defaultHeaders,
              _defaultHeaders,
            ) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.userAgent, userAgent) ||
                other.userAgent == userAgent));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    baseUrl,
    const DeepCollectionEquality().hash(_defaultHeaders),
    timeout,
    userAgent,
  );

  /// Create a copy of NexaHttpClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NexaHttpClientConfigImplCopyWith<_$NexaHttpClientConfigImpl>
  get copyWith =>
      __$$NexaHttpClientConfigImplCopyWithImpl<_$NexaHttpClientConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _NexaHttpClientConfig extends NexaHttpClientConfig {
  const factory _NexaHttpClientConfig({
    final Uri? baseUrl,
    final Map<String, String> defaultHeaders,
    final Duration? timeout,
    final String? userAgent,
  }) = _$NexaHttpClientConfigImpl;
  const _NexaHttpClientConfig._() : super._();

  @override
  Uri? get baseUrl;
  @override
  Map<String, String> get defaultHeaders;
  @override
  Duration? get timeout;
  @override
  String? get userAgent;

  /// Create a copy of NexaHttpClientConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NexaHttpClientConfigImplCopyWith<_$NexaHttpClientConfigImpl>
  get copyWith => throw _privateConstructorUsedError;
}
