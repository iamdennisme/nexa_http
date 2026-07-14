import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:nexa_http_native_macos/nexa_http_native_macos.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetNexaHttpNativeBindingsForTesting);

  test('registerWith installs macOS Native Asset bindings', () {
    NexaHttpNativeMacosPlugin.registerWith();
    expect(
      NexaHttpNativeBindingsRegistry.assetId,
      'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
    );
  });

  test('macOS production plugin has no manual loader or bundle path', () async {
    final contents = await File(
      'lib/src/nexa_http_native_macos_plugin.dart',
    ).readAsString();
    final generated = await File(
      'lib/src/native/nexa_http_native_ffi.dart',
    ).readAsString();
    expect(contents, isNot(contains('DynamicLibrary')));
    expect(contents, isNot(contains('Frameworks')));
    expect(contents, isNot(contains('bundle')));
    expect(
      generated,
      contains(
        "package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart",
      ),
    );
  });
}
