import 'dart:io';

import 'package:nexa_http_native_runtime_internal/nexa_http_native_runtime_internal.dart';
import 'package:nexa_http_native_ios/nexa_http_native_ios.dart';
import 'package:test/test.dart';

void main() {
  test('registerWith installs the iOS runtime', () {
    NexaHttpNativeIosPlugin.registerWith();
    expect(isNexaHttpNativeRuntimeRegistered(), isTrue);
  });

  test('iOS plugin keeps a fixed runtime loading contract', () async {
    final contents = await File(
      'lib/src/nexa_http_native_ios_plugin.dart',
    ).readAsString();

    expect(contents, contains('DynamicLibrary.process()'));
    expect(contents, isNot(contains('NEXA_HTTP_NATIVE_IOS_LIB_PATH')));
    expect(contents, isNot(contains('Platform.environment[_environmentVariable]')));
    expect(contents, isNot(contains('DynamicLibrary.open(explicitPath.trim())')));
    expect(contents, isNot(contains('Frameworks')));
    expect(contents, isNot(contains('target')));
    expect(contents, isNot(contains('walkUpDynamicLibraryCandidates')));
    expect(contents, isNot(contains('resolveNexaHttpDynamicLibraryCandidates')));
  });
}
