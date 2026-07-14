import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('exports the complete stable HTTP Failure Kind taxonomy', () {
    expect(
      NexaHttpFailureKind.values,
      const <NexaHttpFailureKind>[
        NexaHttpFailureKind.canceled,
        NexaHttpFailureKind.timeout,
        NexaHttpFailureKind.network,
        NexaHttpFailureKind.invalidRequest,
        NexaHttpFailureKind.configuration,
        NexaHttpFailureKind.unavailable,
        NexaHttpFailureKind.internal,
      ],
    );
  });

  test('exposes only the typed HTTP Failure fields', () {
    final uri = Uri.parse('https://example.com/items');
    final exception = NexaHttpException(
      kind: NexaHttpFailureKind.timeout,
      message: 'The request timed out.',
      uri: uri,
      diagnostics: const <String, Object?>{
        'native_code': 'timeout',
      },
    );

    expect(exception.kind, NexaHttpFailureKind.timeout);
    expect(exception.message, 'The request timed out.');
    expect(exception.uri, uri);
    expect(exception.diagnostics, const <String, Object?>{
      'native_code': 'timeout',
    });
  });
}
