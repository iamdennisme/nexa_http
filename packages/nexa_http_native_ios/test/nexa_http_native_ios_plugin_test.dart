import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:nexa_http_native_ios/nexa_http_native_ios.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetNexaHttpNativeBindingsForTesting);

  test('registerWith installs iOS Native Asset bindings', () {
    NexaHttpNativeIosPlugin.registerWith();
    expect(
      NexaHttpNativeBindingsRegistry.assetId,
      'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
    );
  });

  test('iOS production plugin has no manual loader', () async {
    final contents = await File(
      'lib/src/nexa_http_native_ios_plugin.dart',
    ).readAsString();
    final generated = await File(
      'lib/src/native/nexa_http_native_ffi.dart',
    ).readAsString();
    expect(contents, isNot(contains('DynamicLibrary')));
    expect(
      generated,
      contains(
        "package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart",
      ),
    );
  });
}
