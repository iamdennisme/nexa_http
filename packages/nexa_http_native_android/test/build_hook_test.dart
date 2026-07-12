import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_android_build_hook;

void main() {
  test(
    'build hook adds the exact prepared Android file as its CodeAsset',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'nexa_http_android_hook_identity_',
      );
      addTearDown(() async => temp.delete(recursive: true));
      final preparedFile = File('${temp.path}/prepared-android.so');
      await preparedFile.writeAsString('prepared');

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: (arguments) => nexa_http_native_android_build_hook.main(
            arguments,
            prepareArtifact:
                ({
                  required packageRoot,
                  required outputDirectory,
                  required targetOS,
                  required targetArchitecture,
                  required targetSdk,
                }) async => preparedFile,
          ),
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
            expect(asset.file, preparedFile.uri);
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
      outputDirectory: p.join(tempDir.path, 'hook-output'),
      targetOS: 'android',
      targetArchitecture: 'arm64',
      targetSdk: null,
      resolveReleaseRef: (_) async => const NexaHttpNativeGitReleaseRef(
        repositorySlug: 'example/nexa_http',
        tag: 'v0.0.3',
      ),
      fetchStream: (uri) async {
        fetchCount += 1;
        if (fetchCount == 1) {
          expect(uri, manifestUri);
          return Stream<List<int>>.value(
            utf8.encode('''
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
'''),
          );
        }
        expect(
          uri,
          Uri.parse(
            'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-android-arm64-v8a.so',
          ),
        );
        return Stream<List<int>>.value(expectedBytes);
      },
    );

    expect(file.existsSync(), isTrue);
    expect(
      file.path,
      endsWith(
        'release/android/arm64/none/nexa_http-native-android-arm64-v8a.so',
      ),
    );
    expect(await file.readAsBytes(), expectedBytes);
  });

  test(
    'release artifact checksum failures include issue-ready context',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nexa_http_android_release_consumer_checksum_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final packageRoot = Directory(
        '${tempDir.path}/packages/nexa_http_native_android',
      )..createSync(recursive: true);

      await expectLater(
        materializeNexaHttpNativeReleaseArtifact(
          packageRoot: packageRoot.path,
          outputDirectory: p.join(tempDir.path, 'hook-output'),
          targetOS: 'android',
          targetArchitecture: 'arm64',
          targetSdk: null,
          resolveReleaseRef: (_) async => const NexaHttpNativeGitReleaseRef(
            repositorySlug: 'example/nexa_http',
            tag: 'v0.0.3',
          ),
          fetchStream: (uri) async {
            if (uri.path.endsWith('nexa_http_native_assets_manifest.json')) {
              return Stream<List<int>>.value(
                utf8.encode('''
{
  "package": "nexa_http",
  "assets": [
    {
      "target_os": "android",
      "target_architecture": "arm64",
      "file_name": "nexa_http-native-android-arm64-v8a.so",
      "source_url": "nexa_http-native-android-arm64-v8a.so",
      "sha256": "${sha256OfString('expected-bytes')}"
    }
  ]
}
'''),
              );
            }
            return Stream<List<int>>.value(utf8.encode('actual-bytes'));
          },
        ),
        throwsA(
          predicate<Object>((error) {
            final text = error.toString();
            return error is NexaHttpNativeArtifactException &&
                text.contains('stage=artifact verification') &&
                text.contains('platform=android') &&
                text.contains('architecture=arm64') &&
                text.contains('sdk_ref=example/nexa_http@v0.0.3') &&
                text.contains('expected_action=') &&
                text.contains('underlying_error=');
          }),
        ),
      );
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
