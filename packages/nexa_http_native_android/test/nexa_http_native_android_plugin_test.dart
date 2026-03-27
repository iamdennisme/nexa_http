import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:nexa_http_native_android/nexa_http_native_android.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Android runtime', () {
    NexaHttpPlatformRegistry.instance = null;
    NexaHttpNativeAndroidPlugin.registerWith();
    expect(NexaHttpPlatformRegistry.instance, isNotNull);
  });
}
