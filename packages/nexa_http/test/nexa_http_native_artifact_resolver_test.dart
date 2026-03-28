import 'dart:convert';
import 'dart:io';

import 'package:nexa_http/src/native_asset/nexa_http_native_artifact_resolver.dart';
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
      packageVersion: '1.0.0',
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

  test('uses a prebuilt file under the source dir override when present', () async {
    final sourceDir = Directory('${tempDir.path}/source')..createSync(recursive: true);
    final sourceOutput = File('${sourceDir.path}/target/debug/libnexa_http_native_macos_ffi.dylib');
    await sourceOutput.parent.create(recursive: true);
    await sourceOutput.writeAsString('source-build');

    final resolved = await resolveNexaHttpNativeArtifactFile(
      packageRoot: tempDir.uri,
      cacheRoot: tempDir.uri,
      packageVersion: '1.0.0',
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
  });

  test('downloads and validates an artifact from a local manifest override', () async {
    final distDir = Directory('${tempDir.path}/dist')..createSync(recursive: true);
    final sourceArtifact = File('${distDir.path}/nexa_http-native-macos-arm64.dylib');
    await sourceArtifact.writeAsString('download-me');
    final digest = sha256OfString('download-me');

    final manifest = File('${tempDir.path}/nexa_http_native_assets_manifest.json');
    await manifest.writeAsString(
      jsonEncode(<String, Object?>{
        'package': 'nexa_http',
        'package_version': '1.0.0',
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
      packageVersion: '1.0.0',
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
  });

  test('prefers manifest download over default source builds for consumers', () async {
    final distDir = Directory('${tempDir.path}/dist')..createSync(recursive: true);
    final sourceArtifact = File('${distDir.path}/nexa_http-native-macos-arm64.dylib');
    await sourceArtifact.writeAsString('manifest-first');
    final digest = sha256OfString('manifest-first');

    final manifest = File('${tempDir.path}/nexa_http_native_assets_manifest.json');
    await manifest.writeAsString(
      jsonEncode(<String, Object?>{
        'package': 'nexa_http',
        'package_version': '1.0.0',
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

    var sourceBuildTriggered = false;
    final resolved = await resolveNexaHttpNativeArtifactFile(
      packageRoot: tempDir.uri,
      cacheRoot: tempDir.uri,
      packageVersion: '1.0.0',
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
      packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
      environment: <String, String>{
        'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifest.path,
      },
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
      defaultSourceDir: '${tempDir.path}/nonexistent-source-dir',
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

  test('default release manifest uri points at the rust_net GitHub release', () {
    final manifestUri = resolveNexaHttpNativeManifestUri(
      packageVersion: '1.0.0',
      environment: const <String, String>{},
    );

    expect(
      manifestUri.toString(),
      'https://github.com/iamdennisme/nexa_http/releases/download/v1.0.0/'
      'nexa_http_native_assets_manifest.json',
    );
  });
}
