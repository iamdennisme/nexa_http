import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:nexa_http_native_ios/nexa_http_native_ios.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the iOS runtime', () {
    NexaHttpPlatformRegistry.instance = null;
    NexaHttpNativeIosPlugin.registerWith();
    expect(NexaHttpPlatformRegistry.instance, isNotNull);
  });
}
