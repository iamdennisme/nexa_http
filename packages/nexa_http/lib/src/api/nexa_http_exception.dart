import 'package:freezed_annotation/freezed_annotation.dart';

part 'nexa_http_exception.freezed.dart';

@freezed
class NexaHttpException with _$NexaHttpException implements Exception {
  const NexaHttpException._();

  const factory NexaHttpException({
    required String code,
    required String message,
    int? statusCode,
    @Default(false) bool isTimeout,
    Uri? uri,
    Map<String, Object?>? details,
  }) = _NexaHttpException;

  @override
  String toString() => 'NexaHttpException(code: $code, message: $message)';
}
