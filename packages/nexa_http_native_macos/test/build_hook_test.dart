import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_macos_build_hook;

void main() {
  test(
    'workspace-dev resolves macOS artifact from source build output',
    () async {
      if (!Platform.isMacOS) {
        markTestSkipped('Requires macOS host.');
        return;
      }

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: nexa_http_native_macos_build_hook.main,
          targetOS: OS.macOS,
          targetArchitecture: Architecture.arm64,
          check: (input, output) async {
            expect(output.assets.code, hasLength(1));
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
            expect(asset.file, isNotNull);
            expect(
              File.fromUri(asset.file!).path,
              endsWith('/target/debug/libnexa_http_native_macos_ffi.dylib'),
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
      Directory('packages/nexa_http_native_macos').existsSync()
      ? Directory('packages/nexa_http_native_macos')
      : originalDirectory;
  Directory.current = packageDirectory.path;
  try {
    return await action();
  } finally {
    Directory.current = originalDirectory.path;
  }
}
