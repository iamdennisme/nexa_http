import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:test/test.dart';

void main() {
  test('throws a clear error when no platform runtime is registered', () {
    NexaHttpPlatformRegistry.instance = null;
    expect(
      () => NexaHttpPlatformRegistry.requireInstance(),
      throwsStateError,
    );
  });
}
