// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'native_http_request_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NativeHttpRequestDto _$NativeHttpRequestDtoFromJson(Map<String, dynamic> json) {
  return _NativeHttpRequestDto.fromJson(json);
}

/// @nodoc
mixin _$NativeHttpRequestDto {
  String get method => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  Map<String, String> get headers => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<int>? get bodyBytes => throw _privateConstructorUsedError;
  @JsonKey(name: 'timeout_ms')
  int? get timeoutMs => throw _privateConstructorUsedError;

  /// Serializes this NativeHttpRequestDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NativeHttpRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NativeHttpRequestDtoCopyWith<NativeHttpRequestDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NativeHttpRequestDtoCopyWith<$Res> {
  factory $NativeHttpRequestDtoCopyWith(NativeHttpRequestDto value,
          $Res Function(NativeHttpRequestDto) then) =
      _$NativeHttpRequestDtoCopyWithImpl<$Res, NativeHttpRequestDto>;
  @useResult
  $Res call(
      {String method,
      String url,
      Map<String, String> headers,
      @JsonKey(includeFromJson: false, includeToJson: false)
      List<int>? bodyBytes,
      @JsonKey(name: 'timeout_ms') int? timeoutMs});
}

/// @nodoc
class _$NativeHttpRequestDtoCopyWithImpl<$Res,
        $Val extends NativeHttpRequestDto>
    implements $NativeHttpRequestDtoCopyWith<$Res> {
  _$NativeHttpRequestDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NativeHttpRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? method = null,
    Object? url = null,
    Object? headers = null,
    Object? bodyBytes = freezed,
    Object? timeoutMs = freezed,
  }) {
    return _then(_value.copyWith(
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      headers: null == headers
          ? _value.headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      bodyBytes: freezed == bodyBytes
          ? _value.bodyBytes
          : bodyBytes // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      timeoutMs: freezed == timeoutMs
          ? _value.timeoutMs
          : timeoutMs // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NativeHttpRequestDtoImplCopyWith<$Res>
    implements $NativeHttpRequestDtoCopyWith<$Res> {
  factory _$$NativeHttpRequestDtoImplCopyWith(_$NativeHttpRequestDtoImpl value,
          $Res Function(_$NativeHttpRequestDtoImpl) then) =
      __$$NativeHttpRequestDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String method,
      String url,
      Map<String, String> headers,
      @JsonKey(includeFromJson: false, includeToJson: false)
      List<int>? bodyBytes,
      @JsonKey(name: 'timeout_ms') int? timeoutMs});
}

/// @nodoc
class __$$NativeHttpRequestDtoImplCopyWithImpl<$Res>
    extends _$NativeHttpRequestDtoCopyWithImpl<$Res, _$NativeHttpRequestDtoImpl>
    implements _$$NativeHttpRequestDtoImplCopyWith<$Res> {
  __$$NativeHttpRequestDtoImplCopyWithImpl(_$NativeHttpRequestDtoImpl _value,
      $Res Function(_$NativeHttpRequestDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of NativeHttpRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? method = null,
    Object? url = null,
    Object? headers = null,
    Object? bodyBytes = freezed,
    Object? timeoutMs = freezed,
  }) {
    return _then(_$NativeHttpRequestDtoImpl(
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      headers: null == headers
          ? _value._headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      bodyBytes: freezed == bodyBytes
          ? _value._bodyBytes
          : bodyBytes // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      timeoutMs: freezed == timeoutMs
          ? _value.timeoutMs
          : timeoutMs // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NativeHttpRequestDtoImpl implements _NativeHttpRequestDto {
  const _$NativeHttpRequestDtoImpl(
      {required this.method,
      required this.url,
      final Map<String, String> headers = const <String, String>{},
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<int>? bodyBytes,
      @JsonKey(name: 'timeout_ms') this.timeoutMs})
      : _headers = headers,
        _bodyBytes = bodyBytes;

  factory _$NativeHttpRequestDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$NativeHttpRequestDtoImplFromJson(json);

  @override
  final String method;
  @override
  final String url;
  final Map<String, String> _headers;
  @override
  @JsonKey()
  Map<String, String> get headers {
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_headers);
  }

  final List<int>? _bodyBytes;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<int>? get bodyBytes {
    final value = _bodyBytes;
    if (value == null) return null;
    if (_bodyBytes is EqualUnmodifiableListView) return _bodyBytes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'timeout_ms')
  final int? timeoutMs;

  @override
  String toString() {
    return 'NativeHttpRequestDto(method: $method, url: $url, headers: $headers, bodyBytes: $bodyBytes, timeoutMs: $timeoutMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NativeHttpRequestDtoImpl &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.url, url) || other.url == url) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            const DeepCollectionEquality()
                .equals(other._bodyBytes, _bodyBytes) &&
            (identical(other.timeoutMs, timeoutMs) ||
                other.timeoutMs == timeoutMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      method,
      url,
      const DeepCollectionEquality().hash(_headers),
      const DeepCollectionEquality().hash(_bodyBytes),
      timeoutMs);

  /// Create a copy of NativeHttpRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NativeHttpRequestDtoImplCopyWith<_$NativeHttpRequestDtoImpl>
      get copyWith =>
          __$$NativeHttpRequestDtoImplCopyWithImpl<_$NativeHttpRequestDtoImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NativeHttpRequestDtoImplToJson(
      this,
    );
  }
}

abstract class _NativeHttpRequestDto implements NativeHttpRequestDto {
  const factory _NativeHttpRequestDto(
          {required final String method,
          required final String url,
          final Map<String, String> headers,
          @JsonKey(includeFromJson: false, includeToJson: false)
          final List<int>? bodyBytes,
          @JsonKey(name: 'timeout_ms') final int? timeoutMs}) =
      _$NativeHttpRequestDtoImpl;

  factory _NativeHttpRequestDto.fromJson(Map<String, dynamic> json) =
      _$NativeHttpRequestDtoImpl.fromJson;

  @override
  String get method;
  @override
  String get url;
  @override
  Map<String, String> get headers;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<int>? get bodyBytes;
  @override
  @JsonKey(name: 'timeout_ms')
  int? get timeoutMs;

  /// Create a copy of NativeHttpRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NativeHttpRequestDtoImplCopyWith<_$NativeHttpRequestDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
