import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('carrier asset adapters do not rediscover legacy package paths', () {
    for (final path in <String>[
      'packages/nexa_http_native_android/lib/src/nexa_http_native_android_asset_bundle.dart',
      'packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_asset_bundle.dart',
      'packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_asset_bundle.dart',
      'packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_asset_bundle.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('resolve(BuildInput')), reason: path);
      expect(source, isNot(contains('jniLibs')), reason: path);
      expect(source, isNot(contains('Frameworks')), reason: path);
      expect(source, isNot(contains('Libraries')), reason: path);
    }
  });

  test('traditional carrier packaging and manual loaders are absent', () {
    final sources = <String>[
      'packages/nexa_http_native_android/android/build.gradle',
      'packages/nexa_http_native_ios/ios/nexa_http_native_ios.podspec',
      'packages/nexa_http_native_macos/macos/nexa_http_native_macos.podspec',
      'packages/nexa_http_native_windows/windows/CMakeLists.txt',
      'packages/nexa_http_native_android/lib/src/nexa_http_native_android_plugin.dart',
      'packages/nexa_http_native_ios/lib/src/nexa_http_native_ios_plugin.dart',
      'packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart',
      'packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart',
      'scripts/build_native_android.sh',
      'scripts/build_native_ios.sh',
      'scripts/build_native_macos.sh',
      'scripts/build_native_windows.sh',
    ];
    for (final path in sources) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('DynamicLibrary.open')), reason: path);
      expect(source, isNot(contains('DynamicLibrary.process')), reason: path);
      expect(
        source,
        isNot(contains('NEXA_HTTP_ANDROID_FORCE_SOURCE_BUILD')),
        reason: path,
      );
      expect(source, isNot(contains('jniLibs.srcDirs')), reason: path);
      expect(source, isNot(contains('preserve_paths')), reason: path);
      expect(source, isNot(contains('resource_bundles')), reason: path);
      expect(source, isNot(contains('android/src/main/jniLibs')), reason: path);
      expect(source, isNot(contains('ios/Frameworks')), reason: path);
      expect(source, isNot(contains('macos/Libraries')), reason: path);
      expect(source, isNot(contains('windows/Libraries')), reason: path);
    }

    for (final path in <String>[
      'packages/nexa_http_native_android/android/src/main/jniLibs',
      'packages/nexa_http_native_ios/ios/Frameworks',
      'packages/nexa_http_native_macos/macos/Libraries',
      'packages/nexa_http_native_windows/windows/Libraries',
    ]) {
      expect(Directory(path).existsSync(), isFalse, reason: path);
    }
  });
}
