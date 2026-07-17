import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/native_transport/native_http_error_dto.dart';
import 'package:nexa_http/src/internal/native_transport/native_http_error_mapper.dart';
import 'package:test/test.dart';

void main() {
  final cases = <String, NexaHttpFailureKind>{
    'canceled': NexaHttpFailureKind.canceled,
    'timeout': NexaHttpFailureKind.timeout,
    'network': NexaHttpFailureKind.network,
    'invalid_request': NexaHttpFailureKind.invalidRequest,
    'invalid_config': NexaHttpFailureKind.configuration,
    'invalid_proxy': NexaHttpFailureKind.configuration,
    'invalid_argument': NexaHttpFailureKind.internal,
    'invalid_utf8': NexaHttpFailureKind.internal,
    'invalid_client': NexaHttpFailureKind.internal,
    'serialization': NexaHttpFailureKind.internal,
    'unexpected_native_code': NexaHttpFailureKind.internal,
  };

  for (final entry in cases.entries) {
    test('maps native ${entry.key} to ${entry.value.name}', () {
      final exception = NativeHttpErrorMapper.toDomain(
        NativeHttpErrorDto(
          code: entry.key,
          message: 'native message',
          uri: 'https://example.com/items',
        ),
      );

      expect(exception.kind, entry.value);
      expect(exception.message, 'native message');
      expect(exception.uri, Uri.parse('https://example.com/items'));
      expect(exception.diagnostics?['native_code'], entry.key);
    });
  }

  test('uses the bootstrap inner configuration code', () {
    final exception = NativeHttpErrorMapper.toDomain(
      const NativeHttpErrorDto(
        code: 'native_bootstrap_failed',
        message: 'bootstrap failed',
        details: <String, dynamic>{
          'stage': 'client_create',
          'native_code': 'invalid_proxy',
        },
      ),
    );

    expect(exception.kind, NexaHttpFailureKind.configuration);
    expect(
      exception.diagnostics,
      containsPair('native_envelope_code', 'native_bootstrap_failed'),
    );
    expect(exception.diagnostics, containsPair('native_code', 'invalid_proxy'));
    expect(exception.diagnostics, containsPair('stage', 'client_create'));
  });

  test('treats the native timeout flag as timeout', () {
    final exception = NativeHttpErrorMapper.toDomain(
      const NativeHttpErrorDto(
        code: 'network',
        message: 'timed out',
        isTimeout: true,
      ),
    );

    expect(exception.kind, NexaHttpFailureKind.timeout);
    expect(exception.diagnostics, containsPair('native_is_timeout', true));
  });

  test('normalizes an invalid native error URI to internal', () {
    final exception = NativeHttpErrorMapper.toDomain(
      const NativeHttpErrorDto(
        code: 'network',
        message: 'network failed',
        uri: 'http://[',
      ),
    );

    expect(exception.kind, NexaHttpFailureKind.internal);
    expect(exception.uri, isNull);
    expect(
      exception.diagnostics,
      containsPair('stage', 'native_error_uri_decode'),
    );
    expect(exception.diagnostics, containsPair('native_code', 'network'));
  });
}
