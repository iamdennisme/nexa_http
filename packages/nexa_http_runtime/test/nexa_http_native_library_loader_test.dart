import 'dart:ffi';

import 'package:nexa_http_runtime/nexa_http_runtime.dart';
import 'package:nexa_http_runtime/src/loader/nexa_http_native_library_loader.dart';
import 'package:nexa_http_runtime/src/loader/nexa_http_native_library_resolver.dart';
import 'package:nexa_http_runtime/src/loader/nexa_http_platform_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  tearDown(() {
    NexaHttpPlatformRegistry.reset();
  });

  test('resolves the Flutter macOS framework path from the app bundle', () {
    final executable = p.join(
      '/Applications',
      'Demo.app',
      'Contents',
      'MacOS',
      'Demo',
    );
    final expected = p.normalize(
      p.join(
        '/Applications',
        'Demo.app',
        'Contents',
        'Frameworks',
        'nexa_http.framework',
        'nexa_http',
      ),
    );

    final candidates = resolveNexaHttpDynamicLibraryCandidates(
      platform: NexaHttpHostPlatform.macos,
      resolvedExecutable: executable,
      currentDirectory: '/tmp',
      fileExists: (path) => p.normalize(path) == expected,
    );

    expect(candidates, contains(expected));
  });

  test('prefers the macOS ffi framework over the wrapper framework', () {
    final executable = p.join(
      '/Applications',
      'Demo.app',
      'Contents',
      'MacOS',
      'Demo',
    );
    final wrapper = p.normalize(
      p.join(
        '/Applications',
        'Demo.app',
        'Contents',
        'Frameworks',
        'nexa_http_native_macos.framework',
        'nexa_http_native_macos',
      ),
    );
    final ffi = p.normalize(
      p.join(
        '/Applications',
        'Demo.app',
        'Contents',
        'Frameworks',
        'nexa_http_native_macos_ffi.framework',
        'nexa_http_native_macos_ffi',
      ),
    );

    final candidates = resolveNexaHttpDynamicLibraryCandidates(
      platform: NexaHttpHostPlatform.macos,
      resolvedExecutable: executable,
      currentDirectory: '/tmp',
      fileExists: (path) {
        final normalized = p.normalize(path);
        return normalized == wrapper || normalized == ffi;
      },
    );

    expect(candidates, isNotEmpty);
    expect(candidates.first, ffi);
  });

  test('resolves the Flutter iOS framework path inside the app bundle', () {
    final executable = p.join('/Applications', 'Demo.app', 'Demo');
    final expected = p.normalize(
      p.join(
        '/Applications',
        'Demo.app',
        'Frameworks',
        'nexa_http.framework',
        'nexa_http',
      ),
    );

    final candidates = resolveNexaHttpDynamicLibraryCandidates(
      platform: NexaHttpHostPlatform.ios,
      resolvedExecutable: executable,
      currentDirectory: '/tmp',
      fileExists: (path) => p.normalize(path) == expected,
    );

    expect(candidates, contains(expected));
  });

  test('resolves the Flutter Windows dll name from the executable folder', () {
    final executable = p.join(r'C:\demo', 'demo.exe');
    final expected = p.normalize(p.join(r'C:\demo', 'nexa_http.dll'));

    final candidates = resolveNexaHttpDynamicLibraryCandidates(
      platform: NexaHttpHostPlatform.windows,
      resolvedExecutable: executable,
      currentDirectory: r'C:\workspace',
      fileExists: (path) => p.normalize(path) == expected,
    );

    expect(candidates, contains(expected));
  });

  test('returns the Android fixed candidate set', () {
    final candidates = resolveNexaHttpDynamicLibraryCandidates(
      platform: NexaHttpHostPlatform.android,
      resolvedExecutable: '/tmp/ignored',
      currentDirectory: '/tmp',
      fileExists: (_) => false,
    );

    expect(candidates, const <String>[
      'libnexa_http_native.so',
      'libnexa_http.so',
      'libnexa_http_native_android_ffi.so',
      'libnexa_http-native-android-arm64.so',
      'libnexa_http-native-android-arm.so',
      'libnexa_http-native-android-x64.so',
    ]);
  });

  test('uses SDK resolved candidates before falling back to the runtime', () {
    final expected = p.normalize(
      p.join(
        '/Applications',
        'Demo.app',
        'Frameworks',
        'nexa_http.framework',
        'nexa_http',
      ),
    );
    final opened = <String>[];
    var runtimeOpenCount = 0;

    final library = loadNexaHttpDynamicLibraryForTesting(
      platform: NexaHttpHostPlatform.ios,
      resolvedExecutable: p.join('/Applications', 'Demo.app', 'Demo'),
      currentDirectory: '/tmp',
      environment: const <String, String>{},
      fileExists: (path) => p.normalize(path) == expected,
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
    expect(opened, contains(expected));
    expect(runtimeOpenCount, 0);
  });

  test(
    'falls back to the registered runtime when SDK candidates are absent',
    () {
      var runtimeOpenCount = 0;

      final library = loadNexaHttpDynamicLibraryForTesting(
        platform: NexaHttpHostPlatform.windows,
        resolvedExecutable: p.join(r'C:\demo', 'demo.exe'),
        currentDirectory: r'C:\workspace',
        environment: const <String, String>{},
        fileExists: (_) => false,
        openDynamicLibrary: (_) => throw ArgumentError('missing'),
        registeredRuntime: _FakeRuntime(() {
          runtimeOpenCount += 1;
          return DynamicLibrary.process();
        }),
      );

      expect(library, isA<DynamicLibrary>());
      expect(runtimeOpenCount, 1);
    },
  );

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
