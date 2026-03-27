import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:nexa_http_native_macos/nexa_http_native_macos.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the macOS runtime', () {
    NexaHttpPlatformRegistry.instance = null;
    NexaHttpNativeMacosPlugin.registerWith();
    expect(NexaHttpPlatformRegistry.instance, isNotNull);
  });
}
