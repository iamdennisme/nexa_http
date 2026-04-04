import 'dart:io';

import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test('workspace package layout includes the merged internal native layer', () {
    final workflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();
    expect(workflow, contains("- 'v*'"));
    expect(workflow, isNot(contains('check-release-train')));
  });

  test('android carrier build.gradle supports workspace target output and final library name', () {
    final buildGradle = File(
      'packages/nexa_http_native_android/android/build.gradle',
    ).readAsStringSync();
    expect(buildGradle, contains('repoRoot'));
    expect(buildGradle, contains('builtLibraryCandidates'));
    expect(buildGradle, contains("rename { 'libnexa_http_native.so' }"));
  });

  test('macOS host architecture helper returns supported values', () {
    if (!Platform.isMacOS) {
      return;
    }
    expect(<String>{'arm64', 'x64'}, contains(currentMacOsArchitecture()));
  });
}
