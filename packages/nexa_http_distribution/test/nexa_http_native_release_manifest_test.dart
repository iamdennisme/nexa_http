import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'nexa-http-native-release-manifest-',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('builds the current native release manifest shape and checksum lines', () async {
    for (final descriptor in nexaHttpNativeReleaseAssetDescriptors) {
      final file = File(p.join(tempDir.path, descriptor.fileName));
      await file.parent.create(recursive: true);
      await file.writeAsString(descriptor.fileName);
    }

    final bundle = await buildNexaHttpNativeReleaseManifest(
      version: '1.2.3',
      distDirectory: tempDir.path,
      generatedAt: DateTime.utc(2026, 4, 1, 12, 0, 0),
      baseUrl: 'https://example.com/download/v1.2.3',
    );

    expect(bundle.manifest['package'], 'nexa_http');
    expect(bundle.manifest['package_version'], '1.2.3');
    expect(bundle.manifest['generated_at'], '2026-04-01T12:00:00.000Z');

    final assets = bundle.manifest['assets'] as List<Object?>;
    expect(
      assets.length,
      nexaHttpNativeReleaseAssetDescriptors.length,
    );

    final firstAsset = assets.first as Map<String, Object?>;
    expect(firstAsset['target_os'], 'android');
    expect(firstAsset['target_architecture'], 'arm64');
    expect(firstAsset['file_name'], 'nexa_http-native-android-arm64-v8a.so');
    expect(
      firstAsset['source_url'],
      'https://example.com/download/v1.2.3/nexa_http-native-android-arm64-v8a.so',
    );

    expect(
      bundle.sha256Lines.first,
      matches(
        RegExp(
          r'^[a-f0-9]{64}  nexa_http-native-android-arm64-v8a\.so$',
        ),
      ),
    );
  });

  test('writes manifest json and checksum output with current filenames', () async {
    for (final descriptor in nexaHttpNativeReleaseAssetDescriptors) {
      final file = File(p.join(tempDir.path, descriptor.fileName));
      await file.parent.create(recursive: true);
      await file.writeAsString('payload:${descriptor.fileName}');
    }

    final outputDir = Directory(p.join(tempDir.path, 'out'));
    await writeNexaHttpNativeReleaseManifestBundle(
      version: '1.2.3',
      distDirectory: tempDir.path,
      outputPath: p.join(outputDir.path, 'nexa_http_native_assets_manifest.json'),
      shaOutputPath: p.join(outputDir.path, 'SHA256SUMS'),
      baseUrl: 'https://example.com/download/v1.2.3',
      generatedAt: DateTime.utc(2026, 4, 1, 12, 0, 0),
    );

    final manifestFile = File(
      p.join(outputDir.path, 'nexa_http_native_assets_manifest.json'),
    );
    final checksumsFile = File(p.join(outputDir.path, 'SHA256SUMS'));

    expect(await manifestFile.exists(), isTrue);
    expect(await checksumsFile.exists(), isTrue);

    final manifestJson =
        jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
    expect(manifestJson['package_version'], '1.2.3');
    expect((manifestJson['assets'] as List<Object?>), hasLength(9));

    final shaLines = await checksumsFile.readAsLines();
    expect(shaLines, hasLength(9));
    expect(
      shaLines.last,
      matches(
        RegExp(r'^[a-f0-9]{64}  nexa_http-native-windows-x64\.dll$'),
      ),
    );
  });
}
