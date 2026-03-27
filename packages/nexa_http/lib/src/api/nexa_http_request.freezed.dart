// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nexa_http_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$NexaHttpRequest {
  NexaHttpMethod get method => throw _privateConstructorUsedError;
  Uri get uri => throw _privateConstructorUsedError;
  Map<String, String> get headers => throw _privateConstructorUsedError;
  List<int>? get bodyBytes => throw _privateConstructorUsedError;
  Duration? get timeout => throw _privateConstructorUsedError;

  /// Create a copy of NexaHttpRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NexaHttpRequestCopyWith<NexaHttpRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NexaHttpRequestCopyWith<$Res> {
  factory $NexaHttpRequestCopyWith(
    NexaHttpRequest value,
    $Res Function(NexaHttpRequest) then,
  ) = _$NexaHttpRequestCopyWithImpl<$Res, NexaHttpRequest>;
  @useResult
  $Res call({
    NexaHttpMethod method,
    Uri uri,
    Map<String, String> headers,
    List<int>? bodyBytes,
    Duration? timeout,
  });
}

/// @nodoc
class _$NexaHttpRequestCopyWithImpl<$Res, $Val extends NexaHttpRequest>
    implements $NexaHttpRequestCopyWith<$Res> {
  _$NexaHttpRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NexaHttpRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? method = null,
    Object? uri = null,
    Object? headers = null,
    Object? bodyBytes = freezed,
    Object? timeout = freezed,
  }) {
    return _then(
      _value.copyWith(
            method: null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                      as NexaHttpMethod,
            uri: null == uri
                ? _value.uri
                : uri // ignore: cast_nullable_to_non_nullable
                      as Uri,
            headers: null == headers
                ? _value.headers
                : headers // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            bodyBytes: freezed == bodyBytes
                ? _value.bodyBytes
                : bodyBytes // ignore: cast_nullable_to_non_nullable
                      as List<int>?,
            timeout: freezed == timeout
                ? _value.timeout
                : timeout // ignore: cast_nullable_to_non_nullable
                      as Duration?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NexaHttpRequestImplCopyWith<$Res>
    implements $NexaHttpRequestCopyWith<$Res> {
  factory _$$NexaHttpRequestImplCopyWith(
    _$NexaHttpRequestImpl value,
    $Res Function(_$NexaHttpRequestImpl) then,
  ) = __$$NexaHttpRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    NexaHttpMethod method,
    Uri uri,
    Map<String, String> headers,
    List<int>? bodyBytes,
    Duration? timeout,
  });
}

/// @nodoc
class __$$NexaHttpRequestImplCopyWithImpl<$Res>
    extends _$NexaHttpRequestCopyWithImpl<$Res, _$NexaHttpRequestImpl>
    implements _$$NexaHttpRequestImplCopyWith<$Res> {
  __$$NexaHttpRequestImplCopyWithImpl(
    _$NexaHttpRequestImpl _value,
    $Res Function(_$NexaHttpRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NexaHttpRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? method = null,
    Object? uri = null,
    Object? headers = null,
    Object? bodyBytes = freezed,
    Object? timeout = freezed,
  }) {
    return _then(
      _$NexaHttpRequestImpl(
        method: null == method
            ? _value.method
            : method // ignore: cast_nullable_to_non_nullable
                  as NexaHttpMethod,
        uri: null == uri
            ? _value.uri
            : uri // ignore: cast_nullable_to_non_nullable
                  as Uri,
        headers: null == headers
            ? _value._headers
            : headers // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        bodyBytes: freezed == bodyBytes
            ? _value._bodyBytes
            : bodyBytes // ignore: cast_nullable_to_non_nullable
                  as List<int>?,
        timeout: freezed == timeout
            ? _value.timeout
            : timeout // ignore: cast_nullable_to_non_nullable
                  as Duration?,
      ),
    );
  }
}

/// @nodoc

class _$NexaHttpRequestImpl extends _NexaHttpRequest {
  const _$NexaHttpRequestImpl({
    required this.method,
    required this.uri,
    final Map<String, String> headers = const <String, String>{},
    final List<int>? bodyBytes,
    this.timeout,
  }) : _headers = headers,
       _bodyBytes = bodyBytes,
       super._();

  @override
  final NexaHttpMethod method;
  @override
  final Uri uri;
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
  List<int>? get bodyBytes {
    final value = _bodyBytes;
    if (value == null) return null;
    if (_bodyBytes is EqualUnmodifiableListView) return _bodyBytes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final Duration? timeout;

  @override
  String toString() {
    return 'NexaHttpRequest(method: $method, uri: $uri, headers: $headers, bodyBytes: $bodyBytes, timeout: $timeout)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NexaHttpRequestImpl &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.uri, uri) || other.uri == uri) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            const DeepCollectionEquality().equals(
              other._bodyBytes,
              _bodyBytes,
            ) &&
            (identical(other.timeout, timeout) || other.timeout == timeout));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    method,
    uri,
    const DeepCollectionEquality().hash(_headers),
    const DeepCollectionEquality().hash(_bodyBytes),
    timeout,
  );

  /// Create a copy of NexaHttpRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NexaHttpRequestImplCopyWith<_$NexaHttpRequestImpl> get copyWith =>
      __$$NexaHttpRequestImplCopyWithImpl<_$NexaHttpRequestImpl>(
        this,
        _$identity,
      );
}

abstract class _NexaHttpRequest extends NexaHttpRequest {
  const factory _NexaHttpRequest({
    required final NexaHttpMethod method,
    required final Uri uri,
    final Map<String, String> headers,
    final List<int>? bodyBytes,
    final Duration? timeout,
  }) = _$NexaHttpRequestImpl;
  const _NexaHttpRequest._() : super._();

  @override
  NexaHttpMethod get method;
  @override
  Uri get uri;
  @override
  Map<String, String> get headers;
  @override
  List<int>? get bodyBytes;
  @override
  Duration? get timeout;

  /// Create a copy of NexaHttpRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NexaHttpRequestImplCopyWith<_$NexaHttpRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
