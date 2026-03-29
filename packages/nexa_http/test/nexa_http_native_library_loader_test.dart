import 'dart:ffi';

import 'package:nexa_http/nexa_http_native_runtime.dart';
import 'package:nexa_http/src/loader/nexa_http_native_library_loader.dart';
import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:test/test.dart';

class _FakeRuntime implements NexaHttpNativeRuntime {
  @override
  DynamicLibrary open() => DynamicLibrary.process();
}

void main() {
  tearDown(() {
    NexaHttpPlatformRegistry.reset();
  });

  test('uses the registered runtime to open the native library', () {
    registerNexaHttpNativeRuntime(_FakeRuntime());
    expect(loadNexaHttpDynamicLibrary(), isA<DynamicLibrary>());
  });
}
