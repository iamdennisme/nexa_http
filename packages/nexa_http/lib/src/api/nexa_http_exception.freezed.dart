// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nexa_http_exception.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$NexaHttpException {
  NexaHttpFailureKind get kind => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  Uri? get uri => throw _privateConstructorUsedError;
  Map<String, Object?>? get diagnostics => throw _privateConstructorUsedError;

  /// Create a copy of NexaHttpException
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NexaHttpExceptionCopyWith<NexaHttpException> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NexaHttpExceptionCopyWith<$Res> {
  factory $NexaHttpExceptionCopyWith(
    NexaHttpException value,
    $Res Function(NexaHttpException) then,
  ) = _$NexaHttpExceptionCopyWithImpl<$Res, NexaHttpException>;
  @useResult
  $Res call({
    NexaHttpFailureKind kind,
    String message,
    Uri? uri,
    Map<String, Object?>? diagnostics,
  });
}

/// @nodoc
class _$NexaHttpExceptionCopyWithImpl<$Res, $Val extends NexaHttpException>
    implements $NexaHttpExceptionCopyWith<$Res> {
  _$NexaHttpExceptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NexaHttpException
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? message = null,
    Object? uri = freezed,
    Object? diagnostics = freezed,
  }) {
    return _then(
      _value.copyWith(
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as NexaHttpFailureKind,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            uri: freezed == uri
                ? _value.uri
                : uri // ignore: cast_nullable_to_non_nullable
                      as Uri?,
            diagnostics: freezed == diagnostics
                ? _value.diagnostics
                : diagnostics // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NexaHttpExceptionImplCopyWith<$Res>
    implements $NexaHttpExceptionCopyWith<$Res> {
  factory _$$NexaHttpExceptionImplCopyWith(
    _$NexaHttpExceptionImpl value,
    $Res Function(_$NexaHttpExceptionImpl) then,
  ) = __$$NexaHttpExceptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    NexaHttpFailureKind kind,
    String message,
    Uri? uri,
    Map<String, Object?>? diagnostics,
  });
}

/// @nodoc
class __$$NexaHttpExceptionImplCopyWithImpl<$Res>
    extends _$NexaHttpExceptionCopyWithImpl<$Res, _$NexaHttpExceptionImpl>
    implements _$$NexaHttpExceptionImplCopyWith<$Res> {
  __$$NexaHttpExceptionImplCopyWithImpl(
    _$NexaHttpExceptionImpl _value,
    $Res Function(_$NexaHttpExceptionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NexaHttpException
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? message = null,
    Object? uri = freezed,
    Object? diagnostics = freezed,
  }) {
    return _then(
      _$NexaHttpExceptionImpl(
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as NexaHttpFailureKind,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        uri: freezed == uri
            ? _value.uri
            : uri // ignore: cast_nullable_to_non_nullable
                  as Uri?,
        diagnostics: freezed == diagnostics
            ? _value._diagnostics
            : diagnostics // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
      ),
    );
  }
}

/// @nodoc

class _$NexaHttpExceptionImpl extends _NexaHttpException {
  const _$NexaHttpExceptionImpl({
    required this.kind,
    required this.message,
    this.uri,
    final Map<String, Object?>? diagnostics,
  }) : _diagnostics = diagnostics,
       super._();

  @override
  final NexaHttpFailureKind kind;
  @override
  final String message;
  @override
  final Uri? uri;
  final Map<String, Object?>? _diagnostics;
  @override
  Map<String, Object?>? get diagnostics {
    final value = _diagnostics;
    if (value == null) return null;
    if (_diagnostics is EqualUnmodifiableMapView) return _diagnostics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NexaHttpExceptionImpl &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.uri, uri) || other.uri == uri) &&
            const DeepCollectionEquality().equals(
              other._diagnostics,
              _diagnostics,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    kind,
    message,
    uri,
    const DeepCollectionEquality().hash(_diagnostics),
  );

  /// Create a copy of NexaHttpException
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NexaHttpExceptionImplCopyWith<_$NexaHttpExceptionImpl> get copyWith =>
      __$$NexaHttpExceptionImplCopyWithImpl<_$NexaHttpExceptionImpl>(
        this,
        _$identity,
      );
}

abstract class _NexaHttpException extends NexaHttpException {
  const factory _NexaHttpException({
    required final NexaHttpFailureKind kind,
    required final String message,
    final Uri? uri,
    final Map<String, Object?>? diagnostics,
  }) = _$NexaHttpExceptionImpl;
  const _NexaHttpException._() : super._();

  @override
  NexaHttpFailureKind get kind;
  @override
  String get message;
  @override
  Uri? get uri;
  @override
  Map<String, Object?>? get diagnostics;

  /// Create a copy of NexaHttpException
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NexaHttpExceptionImplCopyWith<_$NexaHttpExceptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
