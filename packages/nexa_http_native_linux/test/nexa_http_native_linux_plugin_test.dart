import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:nexa_http_native_linux/nexa_http_native_linux.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Linux runtime', () {
    NexaHttpPlatformRegistry.instance = null;
    NexaHttpNativeLinuxPlugin.registerWith();
    expect(NexaHttpPlatformRegistry.instance, isNotNull);
  });
}
