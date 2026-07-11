import 'package:freezed_annotation/freezed_annotation.dart';

part 'nexa_http_exception.freezed.dart';

enum NexaHttpFailureKind {
  canceled,
  timeout,
  network,
  invalidRequest,
  configuration,
  unavailable,
  internal,
}

@freezed
class NexaHttpException with _$NexaHttpException implements Exception {
  const NexaHttpException._();

  const factory NexaHttpException({
    required NexaHttpFailureKind kind,
    required String message,
    Uri? uri,
    Map<String, Object?>? diagnostics,
  }) = _NexaHttpException;

  @override
  String toString() => 'NexaHttpException(kind: $kind, message: $message)';
}
