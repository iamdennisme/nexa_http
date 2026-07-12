import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('same tuple workspace preparation builds once', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_single_flight_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    await Directory(p.join(workspace.path, '.git')).create();
    final script = File(
      p.join(workspace.path, 'scripts', 'build_native_macos.sh'),
    );
    await script.create(recursive: true);
    await File(
      p.join(workspace.path, 'native', 'source.rs'),
    ).create(recursive: true);
    final packageRoot = Directory(
      p.join(workspace.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);
    final outputDirectory = p.join(workspace.path, 'hook-output');
    var buildCount = 0;

    Future<ProcessResult> build(String _, List<String> arguments) async {
      buildCount += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final targetOutputDirectory = arguments[3];
      await File(
        p.join(targetOutputDirectory, 'nexa_http-native-macos-arm64.dylib'),
      ).create(recursive: true);
      return ProcessResult(42, 0, '', '');
    }

    final files = await Future.wait(<Future<File>>[
      for (var index = 0; index < 8; index += 1)
        prepareNexaHttpNativeCarrierArtifact(
          packageRoot: packageRoot.path,
          outputDirectory: outputDirectory,
          targetOS: 'macos',
          targetArchitecture: 'arm64',
          targetSdk: null,
          runProcess: build,
        ),
    ]);

    expect(buildCount, 1);
    expect(files.map((file) => file.absolute.path).toSet(), hasLength(1));
  });

  test('workspace source change invalidates the prepared artifact', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_fingerprint_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    await Directory(p.join(workspace.path, '.git')).create();
    await File(
      p.join(workspace.path, 'scripts', 'build_native_macos.sh'),
    ).create(recursive: true);
    final source = File(p.join(workspace.path, 'native', 'source.rs'));
    await source.create(recursive: true);
    await source.writeAsString('version-1');
    final packageRoot = Directory(
      p.join(workspace.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);
    final outputDirectory = p.join(workspace.path, 'hook-output');
    var buildCount = 0;

    Future<ProcessResult> build(String _, List<String> arguments) async {
      buildCount += 1;
      await File(
        p.join(arguments[3], 'nexa_http-native-macos-arm64.dylib'),
      ).create(recursive: true);
      return ProcessResult(42, 0, '', '');
    }

    Future<void> prepare() async {
      await prepareNexaHttpNativeCarrierArtifact(
        packageRoot: packageRoot.path,
        outputDirectory: outputDirectory,
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        runProcess: build,
      );
    }

    await prepare();
    await source.writeAsString('version-2');
    await prepare();

    expect(buildCount, 2);
  });

  test('same tuple candidate preparation coalesces on one destination', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_single_flight_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final candidateDir = Directory(p.join(tempDir.path, 'candidate'))
      ..createSync();
    const fileName = 'nexa_http-native-macos-arm64.dylib';
    const contents = 'one-candidate-payload';
    await File(p.join(candidateDir.path, fileName)).writeAsString(contents);
    await File(
      p.join(candidateDir.path, 'nexa_http_native_assets_manifest.json'),
    ).writeAsString(
      '{"assets":[{"target_os":"macos","target_architecture":"arm64","file_name":"$fileName","source_url":"$fileName","sha256":"${sha256OfString(contents)}"}]}',
    );
    final outputDirectory = p.join(tempDir.path, 'output');

    final files = await Future.wait(<Future<File>>[
      for (var index = 0; index < 8; index += 1)
        materializeNexaHttpNativeCandidateArtifact(
          outputDirectory: outputDirectory,
          targetOS: 'macos',
          targetArchitecture: 'arm64',
          targetSdk: null,
          candidateDirectory: candidateDir.path,
          candidateRef: 'candidate-1',
        ),
    ]);

    expect(files.map((file) => file.path).toSet(), hasLength(1));
    expect(await files.first.readAsString(), contents);
  });

  test(
    'failed release stream preserves the previous complete destination',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nexa_http_atomic_failure_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final packageRoot = Directory(p.join(tempDir.path, 'package'))
        ..createSync();
      final outputDirectory = p.join(tempDir.path, 'output');
      final target = findNexaHttpNativeTarget(
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
      )!;
      final destination = File(
        p.join(outputDirectory, target.materializationRelativePath('release')),
      );
      await destination.create(recursive: true);
      await destination.writeAsString('previous-complete');
      var fetchCount = 0;

      await expectLater(
        materializeNexaHttpNativeReleaseArtifact(
          packageRoot: packageRoot.path,
          outputDirectory: outputDirectory,
          targetOS: 'macos',
          targetArchitecture: 'arm64',
          targetSdk: null,
          resolveReleaseRef: (_) async => const NexaHttpNativeGitReleaseRef(
            repositorySlug: 'example/nexa_http',
            tag: 'v1.0.0',
          ),
          fetchStream: (_) async {
            fetchCount += 1;
            if (fetchCount == 1) {
              return Stream<List<int>>.value(
                utf8.encode(
                  '{"assets":[{"target_os":"macos","target_architecture":"arm64","file_name":"${target.releaseAssetFileName}","source_url":"${target.releaseAssetFileName}","sha256":"${sha256OfString('expected-new')}"}]}',
                ),
              );
            }
            return Stream<List<int>>.value(utf8.encode('broken-new'));
          },
        ),
        throwsA(isA<NexaHttpNativeArtifactException>()),
      );

      expect(await destination.readAsString(), 'previous-complete');
      expect(
        destination.parent.listSync().whereType<File>().where(
          (file) => file.path.contains('.tmp.'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'carrier consumes an explicit local candidate without fallback',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nexa_http_carrier_candidate_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final candidateDir = Directory(p.join(tempDir.path, 'candidate'))
        ..createSync();
      const fileName = 'nexa_http-native-macos-arm64.dylib';
      const contents = 'candidate-macos-arm64';
      await File(p.join(candidateDir.path, fileName)).writeAsString(contents);
      await File(
        p.join(candidateDir.path, 'nexa_http_native_assets_manifest.json'),
      ).writeAsString('''
{"assets":[{"target_os":"macos","target_architecture":"arm64","file_name":"$fileName","source_url":"$fileName","sha256":"${sha256OfString(contents)}"}]}
''');
      final packageRoot = Directory(
        p.join(tempDir.path, 'packages', 'nexa_http_native_macos'),
      )..createSync(recursive: true);

      final file = await prepareNexaHttpNativeCarrierArtifact(
        packageRoot: packageRoot.path,
        outputDirectory: p.join(tempDir.path, 'hook-output'),
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_CANDIDATE_DIR': candidateDir.path,
          'NEXA_HTTP_NATIVE_CANDIDATE_REF': 'candidate-42',
        },
        runProcess: (_, _) => throw StateError('workspace fallback used'),
        resolveReleaseRef: (_) => throw StateError('release fallback used'),
      );

      expect(await file.readAsString(), contents);
    },
  );

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
    final outputDirectory = p.join(workspace.path, 'hook-output');

    final file = await prepareNexaHttpNativeCarrierArtifact(
      packageRoot: packageRoot.path,
      outputDirectory: outputDirectory,
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
      runProcess: (executable, arguments) async {
        expect(executable, 'bash');
        final targetOutputDirectory = p.join(
          outputDirectory,
          'debug',
          'macos',
          'arm64',
          'none',
        );
        expect(arguments, <String>[
          script.path,
          'debug',
          '--output-dir',
          targetOutputDirectory,
          '--target',
          'aarch64-apple-darwin',
        ]);
        final artifact = File(
          p.join(targetOutputDirectory, 'nexa_http-native-macos-arm64.dylib'),
        );
        await artifact.create(recursive: true);
        await artifact.writeAsString('workspace-artifact');
        return ProcessResult(42, 0, 'ok', '');
      },
    );

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
        outputDirectory: p.join(workspace.path, 'hook-output'),
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
