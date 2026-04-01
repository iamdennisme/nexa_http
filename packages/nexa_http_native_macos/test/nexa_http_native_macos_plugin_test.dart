import 'package:nexa_http_runtime/nexa_http_runtime.dart';
import 'package:nexa_http_native_macos/nexa_http_native_macos.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the macOS runtime', () {
    NexaHttpNativeMacosPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });
}
