import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_ios_build_hook;

void main() {
  test(
    'build hook produces the iOS simulator artifact from the fixed source-build contract',
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
                '/ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib',
              ),
            );
          },
        );
      });
    },
  );

  test('release manifest parser materializes relative iOS asset URL', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_ios_release_consumer_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final packageRoot = Directory(
      '${tempDir.path}/packages/nexa_http_native_ios',
    )..createSync(recursive: true);
    final expectedBytes = utf8.encode('ios-sim-arm64');
    var fetchCount = 0;

    final file = await materializeNexaHttpNativeReleaseArtifact(
      packageRoot: packageRoot.path,
      targetOS: 'ios',
      targetArchitecture: 'arm64',
      targetSdk: 'iphonesimulator',
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
      "target_os": "ios",
      "target_architecture": "arm64",
      "target_sdk": "iphonesimulator",
      "file_name": "nexa_http-native-ios-sim-arm64.dylib",
      "source_url": "nexa_http-native-ios-sim-arm64.dylib",
      "sha256": "${sha256OfString('ios-sim-arm64')}"
    }
  ]
}
''');
        }
        expect(
          uri,
          Uri.parse(
            'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-ios-sim-arm64.dylib',
          ),
        );
        return expectedBytes;
      },
    );

    expect(file.existsSync(), isTrue);
    expect(
      file.path,
      endsWith('ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib'),
    );
    expect(await file.readAsBytes(), expectedBytes);
  });
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
