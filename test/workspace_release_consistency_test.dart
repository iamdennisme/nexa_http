import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test('release-train packages stay on one aligned version and exclude example', () {
    final versions = <String>{};

    for (final packageName in releaseTrainPackageNames) {
      final pubspec = File(
        p.join('packages', packageName, 'pubspec.yaml'),
      ).readAsStringSync();
      final yaml = loadYaml(pubspec) as YamlMap;
      versions.add(yaml['version'] as String);
    }

    final examplePubspec = loadYaml(
      File('packages/nexa_http/example/pubspec.yaml').readAsStringSync(),
    ) as YamlMap;

    expect(versions.length, 1, reason: 'Release-train packages must stay aligned.');
    expect(
      examplePubspec['version'],
      isNot(versions.single),
      reason: 'packages/nexa_http/example is intentionally excluded from the release train.',
    );
  });

  test('release workflow verifies aligned versions for version tags prefixed with v', () {
    final workflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();
    expect(workflow, contains("- 'v*'"));
    expect(
      workflow,
      contains(
        r'dart run scripts/workspace_tools.dart check-release-train --tag "$TAG_NAME"',
      ),
    );
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
