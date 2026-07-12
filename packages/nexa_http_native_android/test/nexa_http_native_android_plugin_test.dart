import 'dart:io';

import 'package:nexa_http_native_android/nexa_http_native_android.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetNexaHttpNativeBindingsForTesting);

  test('registerWith installs Android Native Asset bindings', () {
    NexaHttpNativeAndroidPlugin.registerWith();
    expect(isNexaHttpNativeBindingsRegistered(), isTrue);
    expect(
      NexaHttpNativeBindingsRegistry.assetId,
      'package:nexa_http_native_android/src/native/nexa_http_native_ffi.dart',
    );
  });

  test('Android production plugin has no manual loader', () async {
    final contents = await File(
      'lib/src/nexa_http_native_android_plugin.dart',
    ).readAsString();
    final generated = await File(
      'lib/src/native/nexa_http_native_ffi.dart',
    ).readAsString();
    expect(contents, isNot(contains('DynamicLibrary')));
    expect(
      generated,
      contains(
        "package:nexa_http_native_android/src/native/nexa_http_native_ffi.dart",
      ),
    );
  });
}
