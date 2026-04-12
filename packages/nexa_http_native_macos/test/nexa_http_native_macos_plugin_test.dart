import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
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

    expect(
      contents,
      contains('DynamicLibrary.open(_resolvedBundledLibraryPath())'),
    );
    expect(contents, contains('Platform.resolvedExecutable'));
    expect(contents, contains("'Frameworks'"));
    expect(contents, contains("'nexa_http_native.framework'"));
    expect(contents, contains("'nexa_http_native'"));
    expect(contents, isNot(contains("'nexa_http_native_macos.framework'")));
    expect(contents, isNot(contains("'nexa_http_native.bundle'")));
    expect(contents, isNot(contains("'libnexa_http_native.dylib'")));
    expect(contents, isNot(contains('NEXA_HTTP_NATIVE_MACOS_LIB_PATH')));
    expect(contents, isNot(contains('NEXA_HTTP_NATIVE_MACOS_CONTRACT_PATH')));
    expect(
      contents,
      isNot(contains('Platform.environment[_environmentVariable]')),
    );
    expect(
      contents,
      isNot(contains('DynamicLibrary.open(explicitPath.trim())')),
    );
    expect(contents, isNot(contains('contractPath.trim()')));
    expect(contents, isNot(contains('walkUpDynamicLibraryCandidates')));
  });
}
