import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'nexa-http-native-artifact-resolver-',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('prefers the package-specific lib path override', () async {
    final explicitFile = File('${tempDir.path}/libexplicit.dylib');
    await explicitFile.writeAsString('override');

    final resolved = await resolveNexaHttpNativeArtifactFile(
      packageRoot: tempDir.uri,
      cacheRoot: tempDir.uri,
      mode: NexaHttpNativeArtifactResolutionMode.releaseConsumer,
      releaseIdentity: 'v1.0.1',
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
      packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
      environment: <String, String>{
        'NEXA_HTTP_NATIVE_MACOS_LIB_PATH': explicitFile.path,
      },
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
      sourceDirCandidates: (_) => const <String>[],
    );

    expect(resolved.path, explicitFile.path);
  });

  test(
    'uses a prebuilt file under the source dir override when present',
    () async {
      final sourceDir = Directory('${tempDir.path}/source')
        ..createSync(recursive: true);
      final sourceOutput = File(
        '${sourceDir.path}/target/debug/libnexa_http_native_macos_ffi.dylib',
      );
      await sourceOutput.parent.create(recursive: true);
      await sourceOutput.writeAsString('source-build');

      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.workspaceDev,
        releaseIdentity: 'v1.0.1',
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR': sourceDir.path,
        },
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        sourceDirCandidates: (path) => <String>[
          '$path/target/debug/libnexa_http_native_macos_ffi.dylib',
        ],
      );

      expect(resolved.path, sourceOutput.path);
    },
  );

  test(
    'downloads and validates an artifact from a local manifest override',
    () async {
      final distDir = Directory('${tempDir.path}/dist')
        ..createSync(recursive: true);
      final sourceArtifact = File(
        '${distDir.path}/nexa_http-native-macos-arm64.dylib',
      );
      await sourceArtifact.writeAsString('download-me');
      final digest = sha256OfString('download-me');

      final manifest = File(
        '${tempDir.path}/nexa_http_native_assets_manifest.json',
      );
      await manifest.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'nexa_http',
          'package_version': '1.0.1',
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'macos',
              'target_architecture': 'arm64',
              'file_name': 'nexa_http-native-macos-arm64.dylib',
              'source_url': sourceArtifact.uri.toString(),
              'sha256': digest,
            },
          ],
        }),
      );

      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.releaseConsumer,
        releaseIdentity: 'v1.0.1',
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
        },
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        sourceDirCandidates: (_) => const <String>[],
      );

      expect(await resolved.readAsString(), 'download-me');
    },
  );

  test(
    'release-consumer prefers manifest download over packaged artifacts',
    () async {
      final packagedArtifact = File(
        '${tempDir.path}/macos/Libraries/libnexa_http_native.dylib',
      );
      await packagedArtifact.parent.create(recursive: true);
      await packagedArtifact.writeAsString('packaged-first');

      final distDir = Directory('${tempDir.path}/dist')
        ..createSync(recursive: true);
      final sourceArtifact = File(
        '${distDir.path}/nexa_http-native-macos-arm64.dylib',
      );
      await sourceArtifact.writeAsString('manifest-second');
      final digest = sha256OfString('manifest-second');

      final manifest = File(
        '${tempDir.path}/nexa_http_native_assets_manifest.json',
      );
      await manifest.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'nexa_http',
          'package_version': '1.0.1',
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'macos',
              'target_architecture': 'arm64',
              'file_name': 'nexa_http-native-macos-arm64.dylib',
              'source_url': sourceArtifact.uri.toString(),
              'sha256': digest,
            },
          ],
        }),
      );

      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.releaseConsumer,
        releaseIdentity: 'v1.0.1',
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
        },
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        sourceDirCandidates: (_) => const <String>[],
      );

      expect(await resolved.readAsString(), 'manifest-second');
    },
  );

  test(
    'workspace-dev prefers local source preparation over packaged assets',
    () async {
      final packagedArtifact = File(
        '${tempDir.path}/macos/Libraries/libnexa_http_native.dylib',
      );
      await packagedArtifact.parent.create(recursive: true);
      await packagedArtifact.writeAsString('packaged-copy');

      final distDir = Directory('${tempDir.path}/dist')
        ..createSync(recursive: true);
      final sourceArtifact = File(
        '${distDir.path}/nexa_http-native-macos-arm64.dylib',
      );
      await sourceArtifact.writeAsString('manifest-second');
      final digest = sha256OfString('manifest-second');

      final manifest = File(
        '${tempDir.path}/nexa_http_native_assets_manifest.json',
      );
      await manifest.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'nexa_http',
          'package_version': '1.0.1',
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'macos',
              'target_architecture': 'arm64',
              'file_name': 'nexa_http-native-macos-arm64.dylib',
              'source_url': sourceArtifact.uri.toString(),
              'sha256': digest,
            },
          ],
        }),
      );

      final defaultSourceDir = Directory('${tempDir.path}/default-source-dir')
        ..createSync(recursive: true);
      final builtArtifact = File(
        '${defaultSourceDir.path}/target/debug/libnexa_http_native_macos_ffi.dylib',
      );
      var sourceBuildTriggered = false;
      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.workspaceDev,
        releaseIdentity: 'v1.0.1',
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
        },
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        defaultSourceDir: defaultSourceDir.path,
        buildDefaultSourceDir: (_) async {
          sourceBuildTriggered = true;
          await builtArtifact.parent.create(recursive: true);
          await builtArtifact.writeAsString('source-build-first');
        },
        sourceDirCandidates: (path) => <String>[
          '$path/target/debug/libnexa_http_native_macos_ffi.dylib',
        ],
      );

      expect(await resolved.readAsString(), 'source-build-first');
      expect(sourceBuildTriggered, isTrue);
    },
  );

  test(
    'workspace-dev rebuilds default source artifacts when a stale local binary already exists',
    () async {
      final defaultSourceDir = Directory('${tempDir.path}/default-source-dir')
        ..createSync(recursive: true);
      final existingArtifact = File(
        '${defaultSourceDir.path}/target/debug/libnexa_http_native_macos_ffi.dylib',
      );
      await existingArtifact.parent.create(recursive: true);
      await existingArtifact.writeAsString('stale-local-binary');

      var sourceBuildTriggered = false;
      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.workspaceDev,
        releaseIdentity: 'v1.0.1',
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: const <String, String>{},
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        defaultSourceDir: defaultSourceDir.path,
        buildDefaultSourceDir: (_) async {
          sourceBuildTriggered = true;
          await existingArtifact.writeAsString('rebuilt-from-source');
        },
        sourceDirCandidates: (path) => <String>[
          '$path/target/debug/libnexa_http_native_macos_ffi.dylib',
        ],
      );

      expect(sourceBuildTriggered, isTrue);
      expect(await resolved.readAsString(), 'rebuilt-from-source');
    },
  );

  test('release-consumer forbids implicit local source preparation', () async {
    final distDir = Directory('${tempDir.path}/dist')
      ..createSync(recursive: true);
    final sourceArtifact = File(
      '${distDir.path}/nexa_http-native-macos-arm64.dylib',
    );
    await sourceArtifact.writeAsString('manifest-first');
    final digest = sha256OfString('manifest-first');

    final manifest = File(
      '${tempDir.path}/nexa_http_native_assets_manifest.json',
    );
    await manifest.writeAsString(
      jsonEncode(<String, Object?>{
        'package': 'nexa_http',
        'package_version': '1.0.1',
        'assets': <Map<String, Object?>>[
          <String, Object?>{
            'target_os': 'macos',
            'target_architecture': 'arm64',
            'file_name': 'nexa_http-native-macos-arm64.dylib',
            'source_url': sourceArtifact.uri.toString(),
            'sha256': digest,
          },
        ],
      }),
    );

    final defaultSourceDir = Directory('${tempDir.path}/default-source-dir')
      ..createSync(recursive: true);
    var sourceBuildTriggered = false;
    final resolved = await resolveNexaHttpNativeArtifactFile(
      packageRoot: tempDir.uri,
      cacheRoot: tempDir.uri,
      mode: NexaHttpNativeArtifactResolutionMode.releaseConsumer,
      releaseIdentity: 'v1.0.1',
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
      packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
      environment: <String, String>{
        'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
      },
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
      defaultSourceDir: defaultSourceDir.path,
      buildDefaultSourceDir: (_) async {
        sourceBuildTriggered = true;
      },
      sourceDirCandidates: (path) => <String>[
        '$path/target/debug/libnexa_http_native_macos_ffi.dylib',
      ],
    );

    expect(await resolved.readAsString(), 'manifest-first');
    expect(sourceBuildTriggered, isFalse);
  });

  test(
    'default release manifest uri points at the nexa_http GitHub release',
    () {
      final manifestUri = resolveNexaHttpNativeManifestUri(
        releaseIdentity: 'v1.0.1',
        environment: const <String, String>{},
      );

      expect(
        manifestUri.toString(),
        'https://github.com/iamdennisme/nexa_http/releases/download/v1.0.1/'
        'nexa_http_native_assets_manifest.json',
      );
    },
  );

  test(
    'defaults to workspace-dev for repo checkouts with local native sources',
    () async {
      final packageRoot = Directory(
        '${tempDir.path}/packages/nexa_http_native_macos',
      )..createSync(recursive: true);
      final sourceDir = Directory(
        '${packageRoot.path}/native/nexa_http_native_macos_ffi',
      )..createSync(recursive: true);

      final mode = defaultNexaHttpNativeArtifactResolutionMode(
        packageRoot: packageRoot.uri,
        defaultSourceDir: sourceDir.path,
      );

      expect(mode, NexaHttpNativeArtifactResolutionMode.workspaceDev);
    },
  );

  test(
    'release manifest uri follows the authoritative release identity instead of local package metadata',
    () {
      final manifestUri = resolveNexaHttpNativeManifestUri(
        releaseIdentity: 'v0.0.1',
        environment: const <String, String>{},
      );

      expect(
        manifestUri.toString(),
        'https://github.com/iamdennisme/nexa_http/releases/download/v0.0.1/'
        'nexa_http_native_assets_manifest.json',
      );
    },
  );

  test(
    'release-consumer accepts a tagged release identity even when manifest package metadata differs',
    () async {
      final distDir = Directory('${tempDir.path}/dist')
        ..createSync(recursive: true);
      final sourceArtifact = File(
        '${distDir.path}/nexa_http-native-macos-arm64.dylib',
      );
      await sourceArtifact.writeAsString('tag-first');
      final digest = sha256OfString('tag-first');

      final manifest = File(
        '${tempDir.path}/nexa_http_native_assets_manifest.json',
      );
      await manifest.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'nexa_http',
          'package_version': '0.0.1',
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'macos',
              'target_architecture': 'arm64',
              'file_name': 'nexa_http-native-macos-arm64.dylib',
              'source_url': sourceArtifact.uri.toString(),
              'sha256': digest,
            },
          ],
        }),
      );

      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.releaseConsumer,
        releaseIdentity: 'v0.0.1',
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
        },
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        sourceDirCandidates: (_) => const <String>[],
      );

      expect(await resolved.readAsString(), 'tag-first');
    },
  );

  test(
    'release manifest uri accepts an explicit release base url without release identity',
    () {
      final manifestUri = resolveNexaHttpNativeManifestUri(
        releaseIdentity: null,
        environment: const <String, String>{
          'NEXA_HTTP_NATIVE_RELEASE_BASE_URL':
              'https://example.com/releases/custom',
        },
      );

      expect(
        manifestUri.toString(),
        'https://example.com/releases/custom/'
        'nexa_http_native_assets_manifest.json',
      );
    },
  );

  test(
    'release identity follows explicit environment overrides before git metadata',
    () {
      final releaseIdentity = resolveNexaHttpNativeReleaseIdentity(
        packageRoot: tempDir.uri,
        environment: const <String, String>{
          'NEXA_HTTP_NATIVE_RELEASE_IDENTITY': 'refs/tags/v0.0.1',
        },
      );

      expect(releaseIdentity, 'v0.0.1');
    },
  );

  test(
    'release-consumer uses manifest path override without needing release identity',
    () async {
      final distDir = Directory('${tempDir.path}/dist')
        ..createSync(recursive: true);
      final sourceArtifact = File(
        '${distDir.path}/nexa_http-native-macos-arm64.dylib',
      );
      await sourceArtifact.writeAsString('manifest-override');
      final digest = sha256OfString('manifest-override');

      final manifest = File(
        '${tempDir.path}/nexa_http_native_assets_manifest.json',
      );
      await manifest.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'nexa_http',
          'package_version': '9.9.9',
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'macos',
              'target_architecture': 'arm64',
              'file_name': 'nexa_http-native-macos-arm64.dylib',
              'source_url': sourceArtifact.uri.toString(),
              'sha256': digest,
            },
          ],
        }),
      );

      final resolved = await resolveNexaHttpNativeArtifactFile(
        packageRoot: tempDir.uri,
        cacheRoot: tempDir.uri,
        mode: NexaHttpNativeArtifactResolutionMode.releaseConsumer,
        releaseIdentity: null,
        targetOS: 'macos',
        targetArchitecture: 'arm64',
        targetSdk: null,
        packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
        environment: <String, String>{
          'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
        },
        libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
        sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
        sourceDirCandidates: (_) => const <String>[],
      );

      expect(await resolved.readAsString(), 'manifest-override');
    },
  );

  test(
    'release identity rejects ambiguous git tags on the same commit',
    () async {
      await Process.run('git', [
        'init',
        '-b',
        'main',
      ], workingDirectory: tempDir.path);
      await Process.run('git', [
        'config',
        'user.email',
        'test@example.com',
      ], workingDirectory: tempDir.path);
      await Process.run('git', [
        'config',
        'user.name',
        'Test User',
      ], workingDirectory: tempDir.path);
      final trackedFile = File('${tempDir.path}/README.md');
      await trackedFile.writeAsString('fixture');
      await Process.run('git', [
        'add',
        'README.md',
      ], workingDirectory: tempDir.path);
      await Process.run('git', [
        'commit',
        '-m',
        'fixture',
      ], workingDirectory: tempDir.path);
      await Process.run('git', [
        'tag',
        'v0.0.1',
      ], workingDirectory: tempDir.path);
      await Process.run('git', [
        'tag',
        'v0.0.2',
      ], workingDirectory: tempDir.path);

      expect(
        () => resolveNexaHttpNativeReleaseIdentity(
          packageRoot: tempDir.uri,
          environment: const <String, String>{},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Multiple git tags point at HEAD'),
          ),
        ),
      );
    },
  );
}
