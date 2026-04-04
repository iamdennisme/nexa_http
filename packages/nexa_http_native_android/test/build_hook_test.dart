import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_android_build_hook;

void main() {
  test(
    'build hook produces the Android arm64 artifact from the fixed source-build contract',
    () async {
      if (!await _hasRustTarget('aarch64-linux-android') || !_hasAndroidNdk()) {
        markTestSkipped(
          'Requires rustup target aarch64-linux-android and Android NDK environment.',
        );
        return;
      }

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: nexa_http_native_android_build_hook.main,
          targetOS: OS.android,
          targetArchitecture: Architecture.arm64,
          check: (input, output) async {
            expect(output.assets.code, hasLength(1));
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:nexa_http_native_android/src/native/nexa_http_native_ffi.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
            expect(asset.file, isNotNull);
            final assetPath = asset.file!.path;
            expect(
              assetPath,
              endsWith(
                '/target/aarch64-linux-android/debug/libnexa_http_native_android_ffi.so',
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
      Directory('packages/nexa_http_native_android').existsSync()
      ? Directory('packages/nexa_http_native_android')
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

bool _hasAndroidNdk() {
  final ndkDir =
      Platform.environment['ANDROID_NDK_HOME'] ??
      Platform.environment['ANDROID_NDK_ROOT'];
  if (ndkDir != null && ndkDir.isNotEmpty && Directory(ndkDir).existsSync()) {
    return true;
  }

  final sdkRoot =
      Platform.environment['ANDROID_SDK_ROOT'] ??
      Platform.environment['ANDROID_HOME'];
  if (sdkRoot == null || sdkRoot.isEmpty) {
    return false;
  }

  final ndkRoot = Directory('$sdkRoot/ndk');
  if (!ndkRoot.existsSync()) {
    return false;
  }

  return ndkRoot.listSync(followLinks: false).whereType<Directory>().isNotEmpty;
}
