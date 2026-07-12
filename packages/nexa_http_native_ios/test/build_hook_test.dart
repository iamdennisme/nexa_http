import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_ios_build_hook;

void main() {
  test('build hook adds the exact prepared iOS file as its CodeAsset', () async {
    final temp = await Directory.systemTemp.createTemp(
      'nexa_http_ios_hook_identity_',
    );
    addTearDown(() async => temp.delete(recursive: true));
    final preparedFile = File('${temp.path}/prepared-ios.dylib');
    await preparedFile.writeAsString('prepared');

    await _runInPackageRoot(() async {
      await testCodeBuildHook(
        mainMethod: (arguments) => nexa_http_native_ios_build_hook.main(
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
          expect(asset.file, preparedFile.uri);
        },
      );
    });
  });

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
      outputDirectory: p.join(tempDir.path, 'hook-output'),
      targetOS: 'ios',
      targetArchitecture: 'arm64',
      targetSdk: 'iphonesimulator',
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
      "target_os": "ios",
      "target_architecture": "arm64",
      "target_sdk": "iphonesimulator",
      "file_name": "nexa_http-native-ios-sim-arm64.dylib",
      "source_url": "nexa_http-native-ios-sim-arm64.dylib",
      "sha256": "${sha256OfString('ios-sim-arm64')}"
    }
  ]
}
'''),
          );
        }
        expect(
          uri,
          Uri.parse(
            'https://github.com/example/nexa_http/releases/download/v0.0.3/nexa_http-native-ios-sim-arm64.dylib',
          ),
        );
        return Stream<List<int>>.value(expectedBytes);
      },
    );

    expect(file.existsSync(), isTrue);
    expect(
      file.path,
      endsWith(
        'release/ios/arm64/iphonesimulator/nexa_http-native-ios-sim-arm64.dylib',
      ),
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
