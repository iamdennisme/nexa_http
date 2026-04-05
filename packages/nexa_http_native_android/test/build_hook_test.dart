import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
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
                '/android/src/main/jniLibs/arm64-v8a/libnexa_http_native.so',
              ),
            );
          },
        );
      });
    },
  );

  test('release manifest parser materializes relative Android asset URL', () async {
    final manifestUri = Uri.parse(
      'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http_native_assets_manifest.json',
    );
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_android_release_consumer_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final packageRoot = Directory(
      '${tempDir.path}/packages/nexa_http_native_android',
    )..createSync(recursive: true);
    final expectedBytes = utf8.encode('android-arm64');
    var fetchCount = 0;

    final file = await materializeNexaHttpNativeReleaseArtifact(
      packageRoot: packageRoot.path,
      targetOS: 'android',
      targetArchitecture: 'arm64',
      targetSdk: null,
      resolveReleaseRef: (_) async => const NexaHttpNativeGitReleaseRef(
        repositorySlug: 'example/nexa_http',
        tag: 'v0.0.3',
      ),
      fetchBytes: (uri) async {
        fetchCount += 1;
        if (fetchCount == 1) {
          expect(uri, manifestUri);
          return utf8.encode('''
{
  "package": "nexa_http",
  "assets": [
    {
      "target_os": "android",
      "target_architecture": "arm64",
      "file_name": "nexa_http-native-android-arm64-v8a.so",
      "source_url": "nexa_http-native-android-arm64-v8a.so",
      "sha256": "${sha256OfString('android-arm64')}"
    }
  ]
}
''');
        }
        expect(
          uri,
          Uri.parse(
            'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-android-arm64-v8a.so',
          ),
        );
        return expectedBytes;
      },
    );

    expect(file.existsSync(), isTrue);
    expect(
      file.path,
      endsWith('android/src/main/jniLibs/arm64-v8a/libnexa_http_native.so'),
    );
    expect(await file.readAsBytes(), expectedBytes);
  });
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
