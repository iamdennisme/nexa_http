import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:nexa_http_native_windows/nexa_http_native_windows.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the Windows runtime', () {
    NexaHttpNativeWindowsPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });

  test('Windows plugin keeps a fixed runtime loading contract', () async {
    final contents = await File(
      'lib/src/nexa_http_native_windows_plugin.dart',
    ).readAsString();

    expect(contents, contains("'NEXA_HTTP_NATIVE_WINDOWS_LIB_PATH'"));
    expect(contents, contains("'nexa_http_native.dll'"));
    expect(contents, contains('Platform.environment[_environmentVariable]'));
    expect(contents, contains('DynamicLibrary.open(explicitPath.trim())'));
    expect(contents, contains('DynamicLibrary.open(_libraryFileName)'));
    expect(contents, isNot(contains('windows/Libraries')));
    expect(contents, isNot(contains('target')));
    expect(contents, isNot(contains('walkUpDynamicLibraryCandidates')));
  });
}
