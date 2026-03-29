import 'package:nexa_http/nexa_http_native_runtime.dart';
import 'package:nexa_http_native_windows/nexa_http_native_windows.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Windows runtime', () {
    NexaHttpNativeWindowsPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });
}
