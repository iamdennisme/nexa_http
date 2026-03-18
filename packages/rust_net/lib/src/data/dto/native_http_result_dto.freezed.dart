// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'native_http_result_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NativeHttpResultDto _$NativeHttpResultDtoFromJson(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'success':
      return NativeHttpResultSuccessDto.fromJson(json);
    case 'error':
      return NativeHttpResultErrorDto.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'type', 'NativeHttpResultDto',
          'Invalid union type "${json['type']}"!');
  }
}

/// @nodoc
mixin _$NativeHttpResultDto {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(NativeHttpResponseDto response) success,
    required TResult Function(NativeHttpErrorDto error) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(NativeHttpResponseDto response)? success,
    TResult? Function(NativeHttpErrorDto error)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(NativeHttpResponseDto response)? success,
    TResult Function(NativeHttpErrorDto error)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NativeHttpResultSuccessDto value) success,
    required TResult Function(NativeHttpResultErrorDto value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NativeHttpResultSuccessDto value)? success,
    TResult? Function(NativeHttpResultErrorDto value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NativeHttpResultSuccessDto value)? success,
    TResult Function(NativeHttpResultErrorDto value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this NativeHttpResultDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NativeHttpResultDtoCopyWith<$Res> {
  factory $NativeHttpResultDtoCopyWith(
          NativeHttpResultDto value, $Res Function(NativeHttpResultDto) then) =
      _$NativeHttpResultDtoCopyWithImpl<$Res, NativeHttpResultDto>;
}

/// @nodoc
class _$NativeHttpResultDtoCopyWithImpl<$Res, $Val extends NativeHttpResultDto>
    implements $NativeHttpResultDtoCopyWith<$Res> {
  _$NativeHttpResultDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$NativeHttpResultSuccessDtoImplCopyWith<$Res> {
  factory _$$NativeHttpResultSuccessDtoImplCopyWith(
          _$NativeHttpResultSuccessDtoImpl value,
          $Res Function(_$NativeHttpResultSuccessDtoImpl) then) =
      __$$NativeHttpResultSuccessDtoImplCopyWithImpl<$Res>;
  @useResult
  $Res call({NativeHttpResponseDto response});

  $NativeHttpResponseDtoCopyWith<$Res> get response;
}

/// @nodoc
class __$$NativeHttpResultSuccessDtoImplCopyWithImpl<$Res>
    extends _$NativeHttpResultDtoCopyWithImpl<$Res,
        _$NativeHttpResultSuccessDtoImpl>
    implements _$$NativeHttpResultSuccessDtoImplCopyWith<$Res> {
  __$$NativeHttpResultSuccessDtoImplCopyWithImpl(
      _$NativeHttpResultSuccessDtoImpl _value,
      $Res Function(_$NativeHttpResultSuccessDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? response = null,
  }) {
    return _then(_$NativeHttpResultSuccessDtoImpl(
      response: null == response
          ? _value.response
          : response // ignore: cast_nullable_to_non_nullable
              as NativeHttpResponseDto,
    ));
  }

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NativeHttpResponseDtoCopyWith<$Res> get response {
    return $NativeHttpResponseDtoCopyWith<$Res>(_value.response, (value) {
      return _then(_value.copyWith(response: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$NativeHttpResultSuccessDtoImpl implements NativeHttpResultSuccessDto {
  const _$NativeHttpResultSuccessDtoImpl(
      {required this.response, final String? $type})
      : $type = $type ?? 'success';

  factory _$NativeHttpResultSuccessDtoImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$NativeHttpResultSuccessDtoImplFromJson(json);

  @override
  final NativeHttpResponseDto response;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'NativeHttpResultDto.success(response: $response)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NativeHttpResultSuccessDtoImpl &&
            (identical(other.response, response) ||
                other.response == response));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, response);

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NativeHttpResultSuccessDtoImplCopyWith<_$NativeHttpResultSuccessDtoImpl>
      get copyWith => __$$NativeHttpResultSuccessDtoImplCopyWithImpl<
          _$NativeHttpResultSuccessDtoImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(NativeHttpResponseDto response) success,
    required TResult Function(NativeHttpErrorDto error) error,
  }) {
    return success(response);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(NativeHttpResponseDto response)? success,
    TResult? Function(NativeHttpErrorDto error)? error,
  }) {
    return success?.call(response);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(NativeHttpResponseDto response)? success,
    TResult Function(NativeHttpErrorDto error)? error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(response);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NativeHttpResultSuccessDto value) success,
    required TResult Function(NativeHttpResultErrorDto value) error,
  }) {
    return success(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NativeHttpResultSuccessDto value)? success,
    TResult? Function(NativeHttpResultErrorDto value)? error,
  }) {
    return success?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NativeHttpResultSuccessDto value)? success,
    TResult Function(NativeHttpResultErrorDto value)? error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$NativeHttpResultSuccessDtoImplToJson(
      this,
    );
  }
}

abstract class NativeHttpResultSuccessDto implements NativeHttpResultDto {
  const factory NativeHttpResultSuccessDto(
          {required final NativeHttpResponseDto response}) =
      _$NativeHttpResultSuccessDtoImpl;

  factory NativeHttpResultSuccessDto.fromJson(Map<String, dynamic> json) =
      _$NativeHttpResultSuccessDtoImpl.fromJson;

  NativeHttpResponseDto get response;

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NativeHttpResultSuccessDtoImplCopyWith<_$NativeHttpResultSuccessDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NativeHttpResultErrorDtoImplCopyWith<$Res> {
  factory _$$NativeHttpResultErrorDtoImplCopyWith(
          _$NativeHttpResultErrorDtoImpl value,
          $Res Function(_$NativeHttpResultErrorDtoImpl) then) =
      __$$NativeHttpResultErrorDtoImplCopyWithImpl<$Res>;
  @useResult
  $Res call({NativeHttpErrorDto error});

  $NativeHttpErrorDtoCopyWith<$Res> get error;
}

/// @nodoc
class __$$NativeHttpResultErrorDtoImplCopyWithImpl<$Res>
    extends _$NativeHttpResultDtoCopyWithImpl<$Res,
        _$NativeHttpResultErrorDtoImpl>
    implements _$$NativeHttpResultErrorDtoImplCopyWith<$Res> {
  __$$NativeHttpResultErrorDtoImplCopyWithImpl(
      _$NativeHttpResultErrorDtoImpl _value,
      $Res Function(_$NativeHttpResultErrorDtoImpl) _then)
      : super(_value, _then);

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? error = null,
  }) {
    return _then(_$NativeHttpResultErrorDtoImpl(
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as NativeHttpErrorDto,
    ));
  }

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NativeHttpErrorDtoCopyWith<$Res> get error {
    return $NativeHttpErrorDtoCopyWith<$Res>(_value.error, (value) {
      return _then(_value.copyWith(error: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$NativeHttpResultErrorDtoImpl implements NativeHttpResultErrorDto {
  const _$NativeHttpResultErrorDtoImpl(
      {required this.error, final String? $type})
      : $type = $type ?? 'error';

  factory _$NativeHttpResultErrorDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$NativeHttpResultErrorDtoImplFromJson(json);

  @override
  final NativeHttpErrorDto error;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'NativeHttpResultDto.error(error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NativeHttpResultErrorDtoImpl &&
            (identical(other.error, error) || other.error == error));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, error);

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NativeHttpResultErrorDtoImplCopyWith<_$NativeHttpResultErrorDtoImpl>
      get copyWith => __$$NativeHttpResultErrorDtoImplCopyWithImpl<
          _$NativeHttpResultErrorDtoImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(NativeHttpResponseDto response) success,
    required TResult Function(NativeHttpErrorDto error) error,
  }) {
    return error(this.error);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(NativeHttpResponseDto response)? success,
    TResult? Function(NativeHttpErrorDto error)? error,
  }) {
    return error?.call(this.error);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(NativeHttpResponseDto response)? success,
    TResult Function(NativeHttpErrorDto error)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this.error);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NativeHttpResultSuccessDto value) success,
    required TResult Function(NativeHttpResultErrorDto value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NativeHttpResultSuccessDto value)? success,
    TResult? Function(NativeHttpResultErrorDto value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NativeHttpResultSuccessDto value)? success,
    TResult Function(NativeHttpResultErrorDto value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$NativeHttpResultErrorDtoImplToJson(
      this,
    );
  }
}

abstract class NativeHttpResultErrorDto implements NativeHttpResultDto {
  const factory NativeHttpResultErrorDto(
          {required final NativeHttpErrorDto error}) =
      _$NativeHttpResultErrorDtoImpl;

  factory NativeHttpResultErrorDto.fromJson(Map<String, dynamic> json) =
      _$NativeHttpResultErrorDtoImpl.fromJson;

  NativeHttpErrorDto get error;

  /// Create a copy of NativeHttpResultDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NativeHttpResultErrorDtoImplCopyWith<_$NativeHttpResultErrorDtoImpl>
      get copyWith => throw _privateConstructorUsedError;
}
