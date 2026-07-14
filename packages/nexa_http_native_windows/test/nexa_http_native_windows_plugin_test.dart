import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:nexa_http_native_windows/nexa_http_native_windows.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetNexaHttpNativeBindingsForTesting);

  test('registerWith installs Windows Native Asset bindings', () {
    NexaHttpNativeWindowsPlugin.registerWith();
    expect(
      NexaHttpNativeBindingsRegistry.assetId,
      'package:nexa_http_native_windows/src/native/nexa_http_native_ffi.dart',
    );
  });

  test('Windows production plugin has no manual loader or basename', () async {
    final contents = await File(
      'lib/src/nexa_http_native_windows_plugin.dart',
    ).readAsString();
    final generated = await File(
      'lib/src/native/nexa_http_native_ffi.dart',
    ).readAsString();
    expect(contents, isNot(contains('DynamicLibrary')));
    expect(contents, isNot(contains('.dll')));
    expect(
      generated,
      contains(
        "package:nexa_http_native_windows/src/native/nexa_http_native_ffi.dart",
      ),
    );
  });
}
