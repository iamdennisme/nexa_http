import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_macos_build_hook;

void main() {
  test(
    'build hook adds the exact prepared macOS file as its CodeAsset',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'nexa_http_macos_hook_identity_',
      );
      addTearDown(() async => temp.delete(recursive: true));
      final preparedFile = File('${temp.path}/prepared-macos.dylib');
      await preparedFile.writeAsString('prepared');

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: (arguments) => nexa_http_native_macos_build_hook.main(
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
            expect(asset.file, preparedFile.uri);
          },
        );
      });
    },
  );

  test('release manifest parser materializes relative macOS asset URL', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_macos_release_consumer_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final packageRoot = Directory(
      '${tempDir.path}/packages/nexa_http_native_macos',
    )..createSync(recursive: true);
    final expectedBytes = utf8.encode('macos-arm64');
    var fetchCount = 0;

    final file = await materializeNexaHttpNativeReleaseArtifact(
      packageRoot: packageRoot.path,
      outputDirectory: p.join(tempDir.path, 'hook-output'),
      targetOS: 'macos',
      targetArchitecture: 'arm64',
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
      "target_os": "macos",
      "target_architecture": "arm64",
      "file_name": "nexa_http-native-macos-arm64.dylib",
      "source_url": "nexa_http-native-macos-arm64.dylib",
      "sha256": "${sha256OfString('macos-arm64')}"
    }
  ]
}
'''),
          );
        }
        expect(
          uri,
          Uri.parse(
            'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-macos-arm64.dylib',
          ),
        );
        return Stream<List<int>>.value(expectedBytes);
      },
    );

    expect(file.existsSync(), isTrue);
    expect(
      file.path,
      endsWith('release/macos/arm64/none/nexa_http-native-macos-arm64.dylib'),
    );
    expect(await file.readAsBytes(), expectedBytes);
  });

  test('macOS target exposes the expected rust triple', () {
    final target = findNexaHttpNativeTarget(
      targetOS: 'macos',
      targetArchitecture: 'x64',
      targetSdk: null,
    );

    expect(target, isNotNull);
    expect(target!.rustTargetTriple, 'x86_64-apple-darwin');
  });
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
