import 'package:nexa_http_runtime/nexa_http_runtime.dart';
import 'package:nexa_http_native_ios/nexa_http_native_ios.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the iOS runtime', () {
    NexaHttpNativeIosPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });
}
