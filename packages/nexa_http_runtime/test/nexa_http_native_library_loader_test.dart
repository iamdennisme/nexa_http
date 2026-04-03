import 'dart:ffi';

import '../lib/nexa_http_dynamic_library_loader.dart';
import '../lib/nexa_http_runtime.dart';
import '../lib/src/loader/nexa_http_platform_registry.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    NexaHttpPlatformRegistry.reset();
  });

  test('opens the explicit path before consulting the registered runtime', () {
    final opened = <String>[];
    var runtimeOpenCount = 0;

    final library = loadNexaHttpDynamicLibraryForTesting(
      platform: NexaHttpHostPlatform.macos,
      explicitPath: '/tmp/libnexa_http_native.dylib',
      openDynamicLibrary: (path) {
        opened.add(path);
        return DynamicLibrary.process();
      },
      registeredRuntime: _FakeRuntime(() {
        runtimeOpenCount += 1;
        return DynamicLibrary.process();
      }),
    );

    expect(library, isA<DynamicLibrary>());
    expect(opened, ['/tmp/libnexa_http_native.dylib']);
    expect(runtimeOpenCount, 0);
  });

  test('delegates to the registered runtime when no explicit path is provided', () {
    var runtimeOpenCount = 0;

    final library = loadNexaHttpDynamicLibraryForTesting(
      platform: NexaHttpHostPlatform.windows,
      openDynamicLibrary: (_) =>
          throw StateError('shared loader should not probe candidate paths'),
      registeredRuntime: _FakeRuntime(() {
        runtimeOpenCount += 1;
        return DynamicLibrary.process();
      }),
    );

    expect(library, isA<DynamicLibrary>());
    expect(runtimeOpenCount, 1);
  });

  test('fails with a platform-specific error when no runtime is registered', () {
    expect(
      () => loadNexaHttpDynamicLibraryForTesting(
        platform: NexaHttpHostPlatform.macos,
        openDynamicLibrary: (_) => throw StateError('should not open a path'),
      ),
      throwsA(
        predicate<Object>(
          (error) =>
              error is StateError &&
              error.toString().contains('nexa_http_native_macos'),
        ),
      ),
    );
  });

  test('uses the registered runtime to open the native library', () {
    registerNexaHttpNativeRuntime(_FakeRuntime(DynamicLibrary.process));
    expect(loadNexaHttpDynamicLibrary(), isA<DynamicLibrary>());
  });
}

final class _FakeRuntime implements NexaHttpNativeRuntime {
  _FakeRuntime(this._open);

  final DynamicLibrary Function() _open;

  @override
  DynamicLibrary open() => _open();
}
