import 'package:nexa_http_runtime/nexa_http_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('exports the native runtime SPI from its dedicated package', () {
    expect(registerNexaHttpNativeRuntime, isA<Function>());
    expect(NexaHttpNativeRuntime, isA<Type>());
    expect(isNexaHttpNativeRuntimeRegistered, isA<Function>());
  });
}
