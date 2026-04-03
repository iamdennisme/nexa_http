import 'dart:io';

import 'package:nexa_http_runtime/nexa_http_runtime.dart';
import 'package:nexa_http_native_android/nexa_http_native_android.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Android runtime', () {
    NexaHttpNativeAndroidPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });

  test('Android plugin keeps a fixed runtime loading contract', () async {
    final contents = await File(
      'lib/src/nexa_http_native_android_plugin.dart',
    ).readAsString();

    expect(contents, contains("'NEXA_HTTP_NATIVE_ANDROID_LIB_PATH'"));
    expect(contents, contains("'libnexa_http_native.so'"));
    expect(contents, contains('Platform.environment[_environmentVariable]'));
    expect(contents, contains('DynamicLibrary.open(explicitPath.trim())'));
    expect(contents, contains("DynamicLibrary.open('libnexa_http_native.so')"));
    expect(contents, isNot(contains('target')));
    expect(contents, isNot(contains('walkUpDynamicLibraryCandidates')));
    expect(contents, isNot(contains('resolveNexaHttpDynamicLibraryCandidates')));
  });
}
