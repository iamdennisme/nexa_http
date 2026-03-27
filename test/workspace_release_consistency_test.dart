import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('nexa_http package family uses the 1.0.0 release version', () {
    final packageNames = <String>[
      'nexa_http',
      'nexa_http_native_android',
      'nexa_http_native_ios',
      'nexa_http_native_macos',
      'nexa_http_native_linux',
      'nexa_http_native_windows',
    ];

    for (final packageName in packageNames) {
      final pubspec = File(
        p.join('packages', packageName, 'pubspec.yaml'),
      ).readAsStringSync();
      final yaml = loadYaml(pubspec) as YamlMap;
      expect(
        yaml['version'],
        '1.0.0',
        reason: '$packageName should publish the 1.0.0 package version.',
      );
    }
  });

  test('release workflow supports version tags prefixed with v', () {
    final workflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();
    expect(workflow, contains("- 'v*'"));
    expect(workflow, contains(r'VERSION="${TAG_NAME#v}"'));
  });

  test('android carrier build.gradle supports workspace target output and final library name', () {
    final buildGradle = File(
      'packages/nexa_http_native_android/android/build.gradle',
    ).readAsStringSync();
    expect(buildGradle, contains('repoRoot'));
    expect(buildGradle, contains('builtLibraryCandidates'));
    expect(buildGradle, contains("rename { 'libnexa_http_native.so' }"));
  });
}
