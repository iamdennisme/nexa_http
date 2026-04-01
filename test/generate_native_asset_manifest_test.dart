import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/generate_native_asset_manifest.dart' as generate_manifest;

void main() {
  test('manifest generator script delegates to nexa_http_distribution', () {
    final script = File(
      'scripts/generate_native_asset_manifest.dart',
    ).readAsStringSync();

    expect(
      script,
      contains("package:nexa_http_distribution/nexa_http_distribution.dart"),
    );
  });

  test('manifest generator script preserves current manifest and checksum outputs', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa-http-generate-manifest-script-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final distDir = Directory(p.join(tempDir.path, 'dist-native-assets'))
      ..createSync(recursive: true);
    final fileNames = <String>[
      'nexa_http-native-android-arm64-v8a.so',
      'nexa_http-native-android-armeabi-v7a.so',
      'nexa_http-native-android-x86_64.so',
      'nexa_http-native-ios-arm64.dylib',
      'nexa_http-native-ios-sim-arm64.dylib',
      'nexa_http-native-ios-sim-x64.dylib',
      'nexa_http-native-macos-arm64.dylib',
      'nexa_http-native-macos-x64.dylib',
      'nexa_http-native-windows-x64.dll',
    ];
    for (final fileName in fileNames) {
      await File(p.join(distDir.path, fileName)).writeAsString(fileName);
    }

    final manifestPath = p.join(
      tempDir.path,
      'out',
      'nexa_http_native_assets_manifest.json',
    );
    final shaPath = p.join(tempDir.path, 'out', 'SHA256SUMS');

    await generate_manifest.main(<String>[
      '--version',
      '1.2.3',
      '--dist',
      distDir.path,
      '--output',
      manifestPath,
      '--sha-output',
      shaPath,
      '--base-url',
      'https://example.com/download/v1.2.3',
    ]);

    final manifest = jsonDecode(
      await File(manifestPath).readAsString(),
    ) as Map<String, Object?>;
    final assets = manifest['assets'] as List<Object?>;
    final shaLines = await File(shaPath).readAsLines();

    expect(manifest['package'], 'nexa_http');
    expect(manifest['package_version'], '1.2.3');
    expect(assets, hasLength(9));
    expect(
      (assets.first as Map<String, Object?>)['source_url'],
      'https://example.com/download/v1.2.3/nexa_http-native-android-arm64-v8a.so',
    );
    expect(shaLines, hasLength(9));
  });
}
