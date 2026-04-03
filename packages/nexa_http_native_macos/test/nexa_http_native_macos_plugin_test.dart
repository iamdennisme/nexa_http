import 'dart:io';

import 'package:nexa_http_runtime/nexa_http_runtime.dart';
import 'package:nexa_http_native_macos/nexa_http_native_macos.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the macOS runtime', () {
    NexaHttpNativeMacosPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });

  test('macOS plugin keeps a fixed runtime loading contract', () async {
    final contents = await File(
      'lib/src/nexa_http_native_macos_plugin.dart',
    ).readAsString();

    expect(contents, contains("'NEXA_HTTP_NATIVE_MACOS_LIB_PATH'"));
    expect(contents, contains("'libnexa_http_native.dylib'"));
    expect(contents, contains('Platform.environment[_environmentVariable]'));
    expect(contents, contains('DynamicLibrary.open(explicitPath.trim())'));
    expect(contents, contains('DynamicLibrary.open(_libraryFileName)'));
    expect(contents, isNot(contains('Frameworks')));
    expect(contents, isNot(contains('target')));
    expect(contents, isNot(contains('walkUpDynamicLibraryCandidates')));
  });
}
