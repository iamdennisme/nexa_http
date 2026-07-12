import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'platform build hooks delegate artifact preparation to internal module',
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
          contains('prepareNexaHttpNativeCarrierArtifact'),
          reason: path,
        );
        expect(hook, isNot(contains('Process.run')), reason: path);
        expect(
          hook,
          isNot(contains('materializeNexaHttpNativeReleaseArtifact')),
          reason: path,
        );
      }
    },
  );

  test('macOS native build configures the Xcode SDK', () {
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
