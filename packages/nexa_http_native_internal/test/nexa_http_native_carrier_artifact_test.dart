import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('carrier artifact preparation materializes release artifact', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_carrier_release_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final packageRoot = Directory(
      p.join(tempDir.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);
    final expectedBytes = utf8.encode('macos-arm64');
    var fetchCount = 0;

    final file = await prepareNexaHttpNativeCarrierArtifact(
      packageRoot: packageRoot.path,
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
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
      "target_os": "macos",
      "target_architecture": "arm64",
      "file_name": "nexa_http-native-macos-arm64.dylib",
      "source_url": "nexa_http-native-macos-arm64.dylib",
      "sha256": "${sha256OfString('macos-arm64')}"
    }
  ]
}
''');
        }
        return expectedBytes;
      },
    );

    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('macos/Libraries/libnexa_http_native.dylib'));
    expect(await file.readAsBytes(), expectedBytes);
  });

  test('carrier artifact preparation uses workspace build script', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_carrier_workspace_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await Directory(p.join(workspace.path, '.git')).create();
    final script = File(
      p.join(workspace.path, 'scripts', 'build_native_macos.sh'),
    );
    await script.create(recursive: true);

    final packageRoot = Directory(
      p.join(workspace.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);
    final staleFile = File(
      p.join(packageRoot.path, 'macos', 'Libraries', 'stale.dylib'),
    );
    await staleFile.create(recursive: true);

    final file = await prepareNexaHttpNativeCarrierArtifact(
      packageRoot: packageRoot.path,
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
      runProcess: (executable, arguments) async {
        expect(executable, 'bash');
        expect(arguments, <String>[script.path, 'debug']);
        final artifact = File(
          p.join(
            packageRoot.path,
            'macos',
            'Libraries',
            'libnexa_http_native.dylib',
          ),
        );
        await artifact.create(recursive: true);
        await artifact.writeAsString('workspace-artifact');
        return ProcessResult(42, 0, 'ok', '');
      },
    );

    expect(staleFile.existsSync(), isFalse);
    expect(file.existsSync(), isTrue);
    expect(await file.readAsString(), 'workspace-artifact');
  });

  test('workspace build failure preserves command output', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_carrier_workspace_failure_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await Directory(p.join(workspace.path, '.git')).create();
    final script = File(
      p.join(workspace.path, 'scripts', 'build_native_macos.sh'),
    );
    await script.create(recursive: true);
    final packageRoot = Directory(
      p.join(workspace.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);

    await expectLater(
      prepareNexaHttpNativeCarrierArtifact(
        packageRoot: packageRoot.path,
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        runProcess: (_, _) async => ProcessResult(42, 7, 'stdout', 'stderr'),
      ),
      throwsA(
        isA<ProcessException>()
            .having((error) => error.executable, 'executable', 'bash')
            .having((error) => error.errorCode, 'errorCode', 7)
            .having(
              (error) => error.message,
              'message',
              contains('stdoutstderr'),
            ),
      ),
    );
  });
}
