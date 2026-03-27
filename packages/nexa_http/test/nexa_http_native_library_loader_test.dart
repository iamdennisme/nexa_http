import 'dart:ffi';

import 'package:nexa_http/src/loader/nexa_http_native_library_loader.dart';
import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:test/test.dart';

class _FakeRuntime implements NexaHttpNativeRuntime {
  @override
  DynamicLibrary open() => DynamicLibrary.process();
}

void main() {
  test('uses the registered runtime to open the native library', () {
    NexaHttpPlatformRegistry.instance = _FakeRuntime();
    expect(loadNexaHttpDynamicLibrary(), isA<DynamicLibrary>());
  });
}
