import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('CI consumes Catalog matrices and complete suites only', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(workflow, contains('matrix --suite verify-static'));
    expect(workflow, contains('matrix --suite verify-integration'));
    expect(workflow, matches(RegExp(r'verify-static\s+--execution')));
    expect(workflow, matches(RegExp(r'verify-integration\s+--execution')));
    expect(workflow, contains('verify-static --aggregate-reports'));
    expect(workflow, contains('verify-integration --aggregate-reports'));
    expect(workflow, contains('adb shell service check package'));
    expect(workflow, contains('Android package service did not become ready'));
    expect(workflow, isNot(contains('dart test')));
    expect(workflow, isNot(contains('cargo test')));
    expect(workflow, isNot(contains('build_native_')));
    expect(workflow, isNot(contains('verify-native-abi')));
    expect(workflow, isNot(contains('verify-artifact-consistency')));
    expect(workflow, isNot(contains('continue-on-error')));
  });

  test('unsafe public release workflow is absent', () {
    expect(
      File('.github/workflows/release-native-assets.yml').existsSync(),
      isFalse,
    );
  });
}
