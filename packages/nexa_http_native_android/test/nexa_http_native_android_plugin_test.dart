import 'package:nexa_http/nexa_http_native_runtime.dart';
import 'package:nexa_http_native_android/nexa_http_native_android.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Android runtime', () {
    NexaHttpNativeAndroidPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });
}
