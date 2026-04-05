import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_windows_build_hook;

void main() {
  test(
    'build hook produces the Windows artifact from the fixed source-build contract',
    () async {
      if (!Platform.isWindows ||
          !await _hasRustTarget('x86_64-pc-windows-msvc')) {
        markTestSkipped(
          'Requires Windows host with rustup target x86_64-pc-windows-msvc.',
        );
        return;
      }

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: nexa_http_native_windows_build_hook.main,
          targetOS: OS.windows,
          targetArchitecture: Architecture.x64,
          check: (input, output) async {
            expect(output.assets.code, hasLength(1));
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:nexa_http_native_windows/src/native/nexa_http_native_ffi.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
            expect(asset.file, isNotNull);
            final assetPath = asset.file!.path;
            expect(
              assetPath,
              endsWith('/windows/Libraries/nexa_http_native.dll'),
            );
          },
        );
      });
    },
  );

  test('release manifest parser materializes relative Windows asset URL', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_windows_release_consumer_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final packageRoot = Directory(
      '${tempDir.path}/packages/nexa_http_native_windows',
    )..createSync(recursive: true);
    final expectedBytes = utf8.encode('windows-x64');
    var fetchCount = 0;

    final file = await materializeNexaHttpNativeReleaseArtifact(
      packageRoot: packageRoot.path,
      targetOS: 'windows',
      targetArchitecture: 'x64',
      targetSdk: null,
      resolveReleaseRef: (_) async => const NexaHttpNativeGitReleaseRef(
        repositorySlug: 'example/nexa_http',
        tag: 'v0.0.3',
      ),
      fetchBytes: (uri) async {
        fetchCount += 1;
        if (fetchCount == 1) {
          return utf8.encode('''
{
  "package": "nexa_http",
  "assets": [
    {
      "target_os": "windows",
      "target_architecture": "x64",
      "file_name": "nexa_http-native-windows-x64.dll",
      "source_url": "nexa_http-native-windows-x64.dll",
      "sha256": "${sha256OfString('windows-x64')}"
    }
  ]
}
''');
        }
        expect(
          uri,
          Uri.parse(
            'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-windows-x64.dll',
          ),
        );
        return expectedBytes;
      },
    );

    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('windows/Libraries/nexa_http_native.dll'));
    expect(await file.readAsBytes(), expectedBytes);
  });
}

Future<T> _runInPackageRoot<T>(Future<T> Function() action) async {
  final originalDirectory = Directory.current;
  final packageDirectory =
      Directory('packages/nexa_http_native_windows').existsSync()
      ? Directory('packages/nexa_http_native_windows')
      : originalDirectory;
  Directory.current = packageDirectory.path;
  try {
    return await action();
  } finally {
    Directory.current = originalDirectory.path;
  }
}

Future<bool> _hasRustTarget(String target) async {
  try {
    final result = await Process.run('rustup', <String>[
      'target',
      'list',
      '--installed',
    ]);
    if (result.exitCode != 0) {
      return false;
    }
    return '${result.stdout}'
        .split('\n')
        .map((line) => line.trim())
        .contains(target);
  } catch (_) {
    return false;
  }
}
