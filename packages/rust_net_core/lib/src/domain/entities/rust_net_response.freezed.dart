// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rust_net_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RustNetResponse {
  int get statusCode => throw _privateConstructorUsedError;
  Map<String, List<String>> get headers => throw _privateConstructorUsedError;
  List<int> get bodyBytes => throw _privateConstructorUsedError;
  Uri? get finalUri => throw _privateConstructorUsedError;

  /// Create a copy of RustNetResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RustNetResponseCopyWith<RustNetResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RustNetResponseCopyWith<$Res> {
  factory $RustNetResponseCopyWith(
          RustNetResponse value, $Res Function(RustNetResponse) then) =
      _$RustNetResponseCopyWithImpl<$Res, RustNetResponse>;
  @useResult
  $Res call(
      {int statusCode,
      Map<String, List<String>> headers,
      List<int> bodyBytes,
      Uri? finalUri});
}

/// @nodoc
class _$RustNetResponseCopyWithImpl<$Res, $Val extends RustNetResponse>
    implements $RustNetResponseCopyWith<$Res> {
  _$RustNetResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RustNetResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statusCode = null,
    Object? headers = null,
    Object? bodyBytes = null,
    Object? finalUri = freezed,
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
      bodyBytes: null == bodyBytes
          ? _value.bodyBytes
          : bodyBytes // ignore: cast_nullable_to_non_nullable
              as List<int>,
      finalUri: freezed == finalUri
          ? _value.finalUri
          : finalUri // ignore: cast_nullable_to_non_nullable
              as Uri?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RustNetResponseImplCopyWith<$Res>
    implements $RustNetResponseCopyWith<$Res> {
  factory _$$RustNetResponseImplCopyWith(_$RustNetResponseImpl value,
          $Res Function(_$RustNetResponseImpl) then) =
      __$$RustNetResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int statusCode,
      Map<String, List<String>> headers,
      List<int> bodyBytes,
      Uri? finalUri});
}

/// @nodoc
class __$$RustNetResponseImplCopyWithImpl<$Res>
    extends _$RustNetResponseCopyWithImpl<$Res, _$RustNetResponseImpl>
    implements _$$RustNetResponseImplCopyWith<$Res> {
  __$$RustNetResponseImplCopyWithImpl(
      _$RustNetResponseImpl _value, $Res Function(_$RustNetResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of RustNetResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statusCode = null,
    Object? headers = null,
    Object? bodyBytes = null,
    Object? finalUri = freezed,
  }) {
    return _then(_$RustNetResponseImpl(
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int,
      headers: null == headers
          ? _value._headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      bodyBytes: null == bodyBytes
          ? _value._bodyBytes
          : bodyBytes // ignore: cast_nullable_to_non_nullable
              as List<int>,
      finalUri: freezed == finalUri
          ? _value.finalUri
          : finalUri // ignore: cast_nullable_to_non_nullable
              as Uri?,
    ));
  }
}

/// @nodoc

class _$RustNetResponseImpl extends _RustNetResponse {
  const _$RustNetResponseImpl(
      {required this.statusCode,
      final Map<String, List<String>> headers = const <String, List<String>>{},
      final List<int> bodyBytes = const <int>[],
      this.finalUri})
      : _headers = headers,
        _bodyBytes = bodyBytes,
        super._();

  @override
  final int statusCode;
  final Map<String, List<String>> _headers;
  @override
  @JsonKey()
  Map<String, List<String>> get headers {
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_headers);
  }

  final List<int> _bodyBytes;
  @override
  @JsonKey()
  List<int> get bodyBytes {
    if (_bodyBytes is EqualUnmodifiableListView) return _bodyBytes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bodyBytes);
  }

  @override
  final Uri? finalUri;

  @override
  String toString() {
    return 'RustNetResponse(statusCode: $statusCode, headers: $headers, bodyBytes: $bodyBytes, finalUri: $finalUri)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RustNetResponseImpl &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            const DeepCollectionEquality()
                .equals(other._bodyBytes, _bodyBytes) &&
            (identical(other.finalUri, finalUri) ||
                other.finalUri == finalUri));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      statusCode,
      const DeepCollectionEquality().hash(_headers),
      const DeepCollectionEquality().hash(_bodyBytes),
      finalUri);

  /// Create a copy of RustNetResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RustNetResponseImplCopyWith<_$RustNetResponseImpl> get copyWith =>
      __$$RustNetResponseImplCopyWithImpl<_$RustNetResponseImpl>(
          this, _$identity);
}

abstract class _RustNetResponse extends RustNetResponse {
  const factory _RustNetResponse(
      {required final int statusCode,
      final Map<String, List<String>> headers,
      final List<int> bodyBytes,
      final Uri? finalUri}) = _$RustNetResponseImpl;
  const _RustNetResponse._() : super._();

  @override
  int get statusCode;
  @override
  Map<String, List<String>> get headers;
  @override
  List<int> get bodyBytes;
  @override
  Uri? get finalUri;

  /// Create a copy of RustNetResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RustNetResponseImplCopyWith<_$RustNetResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
