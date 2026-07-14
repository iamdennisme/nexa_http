import '../../api/nexa_http_exception.dart';

final class NexaHttpFailures {
  const NexaHttpFailures._();

  static NexaHttpException canceled({required String stage, Uri? uri}) {
    return NexaHttpException(
      kind: NexaHttpFailureKind.canceled,
      message: 'The request was canceled.',
      uri: uri,
      diagnostics: <String, Object?>{'stage': stage},
    );
  }

  static NexaHttpException unavailable({
    required String message,
    required String stage,
    Uri? uri,
    Object? error,
    Map<String, Object?>? diagnostics,
  }) {
    return NexaHttpException(
      kind: NexaHttpFailureKind.unavailable,
      message: message,
      uri: uri,
      diagnostics: <String, Object?>{
        'stage': stage,
        ...?diagnostics,
        if (error != null) 'error_type': error.runtimeType.toString(),
        if (error != null) 'error': error.toString(),
      },
    );
  }

  static NexaHttpException internal({
    required String message,
    required String stage,
    Uri? uri,
    Object? error,
    Map<String, Object?>? diagnostics,
  }) {
    return NexaHttpException(
      kind: NexaHttpFailureKind.internal,
      message: message,
      uri: uri,
      diagnostics: <String, Object?>{
        'stage': stage,
        ...?diagnostics,
        if (error != null) 'error_type': error.runtimeType.toString(),
        if (error != null) 'error': error.toString(),
      },
    );
  }
}
