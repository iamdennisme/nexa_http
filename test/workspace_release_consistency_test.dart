import 'dart:io';

import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test(
    'workspace package layout includes the merged internal native layer',
    () {
      final workflow = File(
        '.github/workflows/release-native-assets.yml',
      ).readAsStringSync();
      expect(workflow, contains("- 'v*'"));
      expect(workflow, isNot(contains('check-release-train')));
    },
  );

  test(
    'android carrier build.gradle supports workspace target output and final library name',
    () {
      final buildGradle = File(
        'packages/nexa_http_native_android/android/build.gradle',
      ).readAsStringSync();
      expect(buildGradle, contains('repoRoot'));
      expect(buildGradle, contains('builtLibraryCandidates'));
      expect(buildGradle, contains("rename { 'libnexa_http_native.so' }"));
      expect(
        buildGradle,
        contains('NEXA_HTTP_ANDROID_FORCE_SOURCE_BUILD=true'),
      );
      expect(buildGradle, contains('stage=native packaging; platform=android'));
      expect(
        buildGradle,
        isNot(contains('rebuilding Android jniLibs because')),
      );
    },
  );

  test(
    'platform build hooks do not classify tagged pub-cache git dependencies as workspace packages',
    () {
      for (final path in <String>[
        'packages/nexa_http_native_android/hook/build.dart',
        'packages/nexa_http_native_ios/hook/build.dart',
        'packages/nexa_http_native_macos/hook/build.dart',
        'packages/nexa_http_native_windows/hook/build.dart',
      ]) {
        final hook = File(path).readAsStringSync();
        expect(
          hook,
          contains('shouldBuildNexaHttpNativeFromWorkspaceSource'),
          reason: path,
        );
        expect(
          hook,
          isNot(contains('Directory(p.join(workspaceRoot, \'.git\'))')),
        );
      }
    },
  );

  test('macOS host architecture helper returns supported values', () {
    if (!Platform.isMacOS) {
      return;
    }
    expect(<String>{'arm64', 'x64'}, contains(currentMacOsArchitecture()));
  });

  test('macOS native build configures Xcode SDK for C dependencies', () {
    final commonScript = File(
      'scripts/build_native_common.sh',
    ).readAsStringSync();
    final macosScript = File(
      'scripts/build_native_macos.sh',
    ).readAsStringSync();

    expect(commonScript, contains('configure_macos_sdk_env'));
    expect(commonScript, contains('xcrun --sdk macosx --show-sdk-path'));
    expect(commonScript, contains(r'-isysroot ${SDKROOT}'));
    expect(macosScript, contains('configure_macos_sdk_env'));
  });

  test('native build scripts bound rustup target installation', () {
    final commonScript = File(
      'scripts/build_native_common.sh',
    ).readAsStringSync();

    expect(commonScript, contains('rustup target list --installed'));
    expect(commonScript, contains('run_with_timeout 600 rustup target add'));
    expect(commonScript, contains('Command timed out after'));
  });
}
