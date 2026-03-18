import 'package:freezed_annotation/freezed_annotation.dart';

part 'rust_net_exception.freezed.dart';

@freezed
class RustNetException with _$RustNetException implements Exception {
  const RustNetException._();

  const factory RustNetException({
    required String code,
    required String message,
    int? statusCode,
    @Default(false) bool isTimeout,
    Uri? uri,
    Map<String, Object?>? details,
  }) = _RustNetException;

  @override
  String toString() => 'RustNetException(code: $code, message: $message)';
}
