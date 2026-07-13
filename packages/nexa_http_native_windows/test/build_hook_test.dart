import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_windows_build_hook;

void main() {
  test(
    'build hook adds the exact prepared Windows file as its CodeAsset',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'nexa_http_windows_hook_identity_',
      );
      addTearDown(() async => temp.delete(recursive: true));
      final preparedFile = File('${temp.path}/prepared-windows.dll');
      await preparedFile.writeAsString('prepared');

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: (arguments) => nexa_http_native_windows_build_hook.main(
            arguments,
            prepareArtifact:
                ({
                  required packageRoot,
                  required outputDirectory,
                  required targetOS,
                  required targetArchitecture,
                  required targetSdk,
                  candidateDirectory,
                  candidateRef,
                }) async {
                  expect(candidateDirectory, p.join(temp.path, 'candidate'));
                  expect(candidateRef, 'candidate-42');
                  return preparedFile;
                },
          ),
          targetOS: OS.windows,
          targetArchitecture: Architecture.x64,
          userDefines: PackageUserDefines(
            workspacePubspec: PackageUserDefinesSource(
              defines: const <String, Object?>{
                nexaHttpNativeCandidateDirectoryDefine: 'candidate',
                nexaHttpNativeCandidateRefDefine: 'candidate-42',
              },
              basePath: temp.uri,
            ),
          ),
          check: (input, output) async {
            expect(output.assets.code, hasLength(1));
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:nexa_http_native_windows/src/native/nexa_http_native_ffi.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
            expect(asset.file, isNotNull);
            expect(asset.file, preparedFile.uri);
          },
        );
      });
    },
  );

  test(
    'release manifest parser materializes relative Windows asset URL',
    () async {
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
        outputDirectory: p.join(tempDir.path, 'hook-output'),
        targetOS: 'windows',
        targetArchitecture: 'x64',
        targetSdk: null,
        resolveReleaseRef: (_) async => const NexaHttpNativeGitReleaseRef(
          repositorySlug: 'example/nexa_http',
          tag: 'v0.0.3',
        ),
        fetchStream: (uri) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return Stream<List<int>>.value(
              utf8.encode('''
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
'''),
            );
          }
          expect(
            uri,
            Uri.parse(
              'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-windows-x64.dll',
            ),
          );
          return Stream<List<int>>.value(expectedBytes);
        },
      );

      expect(file.existsSync(), isTrue);
      expect(
        file.path,
        endsWith('release/windows/x64/none/nexa_http-native-windows-x64.dll'),
      );
      expect(await file.readAsBytes(), expectedBytes);
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
