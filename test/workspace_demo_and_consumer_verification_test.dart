import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('root hook entrypoints keep workspace self-import resolution', () {
    final rootPubspec = File('pubspec.yaml').readAsStringSync();
    expect(rootPubspec, contains('code_assets: ^1.0.0'));
    expect(rootPubspec, contains('hooks: ^1.0.2'));

    for (final entry in <(String, String)>[
      (
        'packages/nexa_http_native_android/hook/build.dart',
        "import '../lib/src/nexa_http_native_android_asset_bundle.dart';",
      ),
      (
        'packages/nexa_http_native_ios/hook/build.dart',
        "import '../lib/src/nexa_http_native_ios_asset_bundle.dart';",
      ),
      (
        'packages/nexa_http_native_macos/hook/build.dart',
        "import '../lib/src/nexa_http_native_macos_asset_bundle.dart';",
      ),
      (
        'packages/nexa_http_native_windows/hook/build.dart',
        "import '../lib/src/nexa_http_native_windows_asset_bundle.dart';",
      ),
    ]) {
      expect(File(entry.$1).readAsStringSync(), contains(entry.$2));
    }
  });

  test('official demo declares and contains all supported platforms', () {
    final pubspec = File(
      p.join('app', 'demo', 'pubspec.yaml'),
    ).readAsStringSync();
    for (final platform in <String>['android', 'ios', 'macos', 'windows']) {
      expect(Directory(p.join('app', 'demo', platform)).existsSync(), isTrue);
      expect(pubspec, contains('nexa_http_native_$platform:'));
    }
    expect(pubspec, contains('nexa_http:'));
    expect(pubspec, isNot(contains('nexa_http_native_internal:')));
  });

  test('public package documentation keeps native internals hidden', () {
    final readme = File(
      p.join('packages', 'nexa_http', 'README.md'),
    ).readAsStringSync();
    expect(readme, contains('nexa_http:'));
    expect(readme, contains('nexa_http_native_macos:'));
    expect(readme, isNot(contains('nexa_http_native_internal:')));
  });
}
