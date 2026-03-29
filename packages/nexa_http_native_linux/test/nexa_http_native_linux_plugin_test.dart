import 'package:nexa_http/nexa_http_native_runtime.dart';
import 'package:nexa_http_native_linux/nexa_http_native_linux.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Linux runtime', () {
    NexaHttpNativeLinuxPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });
}
