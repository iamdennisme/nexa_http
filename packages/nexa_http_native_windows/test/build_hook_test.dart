import 'dart:io';

import 'package:code_assets/code_assets.dart';
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
              endsWith(
                '/target/x86_64-pc-windows-msvc/debug/nexa_http_native_windows_ffi.dll',
              ),
            );
          },
        );
      });
    },
  );
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
