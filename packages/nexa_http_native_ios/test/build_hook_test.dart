import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_ios_build_hook;

void main() {
  test(
    'workspace-dev resolves iOS simulator artifact from source build output',
    () async {
      if (!Platform.isMacOS || !await _hasRustTarget('aarch64-apple-ios-sim')) {
        markTestSkipped(
          'Requires macOS host with rustup target aarch64-apple-ios-sim.',
        );
        return;
      }

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: nexa_http_native_ios_build_hook.main,
          targetOS: OS.iOS,
          targetArchitecture: Architecture.arm64,
          targetIOSSdk: IOSSdk.iPhoneSimulator,
          check: (input, output) async {
            expect(output.assets.code, hasLength(1));
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
            expect(asset.file, isNotNull);
            final assetPath = asset.file!.path;
            expect(
              assetPath,
              endsWith(
                '/target/aarch64-apple-ios-sim/debug/libnexa_http_native_ios_ffi.dylib',
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
      Directory('packages/nexa_http_native_ios').existsSync()
      ? Directory('packages/nexa_http_native_ios')
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
