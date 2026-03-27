import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:nexa_http_native_windows/nexa_http_native_windows.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Windows runtime', () {
    NexaHttpPlatformRegistry.instance = null;
    NexaHttpNativeWindowsPlugin.registerWith();
    expect(NexaHttpPlatformRegistry.instance, isNotNull);
  });
}
