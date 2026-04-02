import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test(
    'workspace tools expose development-path, release-consumer, and artifact-consistency verification commands',
    () {
      expect(
        workspaceVerificationCommands,
        contains('verify-artifact-consistency'),
      );
      expect(
        workspaceVerificationCommands,
        contains('verify-development-path'),
      );
      expect(
        workspaceVerificationCommands,
        contains('verify-release-consumer'),
      );
    },
  );

  test('release workflow and target matrix stay aligned for native assets', () {
    final workflow = File(
      p.join('.github', 'workflows', 'release-native-assets.yml'),
    ).readAsStringSync();

    final copiedAssets = RegExp(r'dist/native-assets/([A-Za-z0-9._-]+)')
        .allMatches(workflow)
        .map((match) => match.group(1)!)
        .where((value) => value != '*')
        .toSet();

    final expectedAssets = releaseTrainNativeAssetFileNames().toSet();

    expect(copiedAssets, containsAll(expectedAssets));
    expect(expectedAssets, containsAll(copiedAssets));
    expect(workflow, contains('verify-artifact-consistency'));
    expect(workflow, contains('check-release-train'));
  });

  test(
    'pr CI workflow blocks on development-path, artifact-consistency, and release-consumer verification',
    () {
      final workflow = File(
        p.join('.github', 'workflows', 'ci.yml'),
      ).readAsStringSync();

      expect(workflow, contains('ubuntu-latest'));
      expect(workflow, contains('macos-14'));
      expect(workflow, contains('windows-latest'));
      expect(workflow, contains('verify-artifact-consistency'));
      expect(workflow, contains('verify-development-path'));
      expect(workflow, contains('verify-release-consumer'));
    },
  );

  test(
    'workspace-dev hook resolution is source-authoritative for all carrier packages',
    () {
      final hookFiles = <String, String>{
        'android': p.join(
          'packages',
          'nexa_http_native_android',
          'hook',
          'build.dart',
        ),
        'ios': p.join('packages', 'nexa_http_native_ios', 'hook', 'build.dart'),
        'macos': p.join(
          'packages',
          'nexa_http_native_macos',
          'hook',
          'build.dart',
        ),
        'windows': p.join(
          'packages',
          'nexa_http_native_windows',
          'hook',
          'build.dart',
        ),
      };

      for (final entry in hookFiles.entries) {
        final source = File(entry.value).readAsStringSync();
        expect(
          source,
          contains('buildDefaultSourceDir:'),
          reason:
              '${entry.key} hook must pass buildDefaultSourceDir so workspace-dev prepares native artifacts from source.',
        );
      }
    },
  );

  test(
    'root hook test entrypoint keeps package resolution for workspace hook self imports',
    () {
      final rootPubspec = File('pubspec.yaml').readAsStringSync();
      expect(rootPubspec, contains('code_assets: ^1.0.0'));
      expect(rootPubspec, contains('hooks: ^1.0.2'));

      final androidHook = File(
        p.join('packages', 'nexa_http_native_android', 'hook', 'build.dart'),
      ).readAsStringSync();
      expect(
        androidHook,
        contains(
          "import '../lib/src/nexa_http_native_android_asset_bundle.dart';",
        ),
      );
      expect(
        androidHook,
        isNot(
          contains(
            "import 'package:nexa_http_native_android/src/nexa_http_native_android_asset_bundle.dart';",
          ),
        ),
      );

      final iosHook = File(
        p.join('packages', 'nexa_http_native_ios', 'hook', 'build.dart'),
      ).readAsStringSync();
      expect(
        iosHook,
        contains("import '../lib/src/nexa_http_native_ios_asset_bundle.dart';"),
      );
      expect(
        iosHook,
        isNot(
          contains(
            "import 'package:nexa_http_native_ios/src/nexa_http_native_ios_asset_bundle.dart';",
          ),
        ),
      );

      final macosHook = File(
        p.join('packages', 'nexa_http_native_macos', 'hook', 'build.dart'),
      ).readAsStringSync();
      expect(
        macosHook,
        contains(
          "import '../lib/src/nexa_http_native_macos_asset_bundle.dart';",
        ),
      );
      expect(
        macosHook,
        isNot(
          contains(
            "import 'package:nexa_http_native_macos/src/nexa_http_native_macos_asset_bundle.dart';",
          ),
        ),
      );

      final windowsHook = File(
        p.join('packages', 'nexa_http_native_windows', 'hook', 'build.dart'),
      ).readAsStringSync();
      expect(
        windowsHook,
        contains(
          "import '../lib/src/nexa_http_native_windows_asset_bundle.dart';",
        ),
      );
      expect(
        windowsHook,
        isNot(
          contains(
            "import 'package:nexa_http_native_windows/src/nexa_http_native_windows_asset_bundle.dart';",
          ),
        ),
      );
    },
  );

  test('example README documents all supported platform run targets', () {
    final readme = File(
      p.join('packages', 'nexa_http', 'example', 'README.md'),
    ).readAsStringSync();

    expect(readme, contains('flutter run -d macos'));
    expect(readme, contains('flutter run -d windows'));
    expect(readme, contains('flutter run -d android'));
    expect(readme, contains('flutter run -d ios'));
  });

  test(
    'official example contains platform projects for every supported demo target',
    () {
      expect(
        Directory(
          p.join('packages', 'nexa_http', 'example', 'android'),
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory(
          p.join('packages', 'nexa_http', 'example', 'ios'),
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory(
          p.join('packages', 'nexa_http', 'example', 'macos'),
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory(
          p.join('packages', 'nexa_http', 'example', 'windows'),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'public package README presents nexa_http as the only consumer dependency',
    () {
      final readme = File(
        p.join('packages', 'nexa_http', 'README.md'),
      ).readAsStringSync();

      expect(readme, isNot(contains('nexa_http_runtime:')));
      expect(readme, isNot(contains('nexa_http_distribution:')));
      expect(readme, isNot(contains('nexa_http_native_macos:')));
      expect(readme, isNot(contains('nexa_http_native_ios:')));
      expect(readme, isNot(contains('nexa_http_native_android:')));
      expect(readme, isNot(contains('nexa_http_native_windows:')));
      expect(readme, contains('nexa_http:'));
      expect(readme, contains('git:'));
    },
  );

  test('official example depends only on nexa_http at the app layer', () {
    final pubspec = File(
      p.join('packages', 'nexa_http', 'example', 'pubspec.yaml'),
    ).readAsStringSync();

    expect(pubspec, contains('nexa_http:'));
    expect(pubspec, isNot(contains('nexa_http_native_android:')));
    expect(pubspec, isNot(contains('nexa_http_native_ios:')));
    expect(pubspec, isNot(contains('nexa_http_native_macos:')));
    expect(pubspec, isNot(contains('nexa_http_native_windows:')));
  });

  test(
    'nexa_http pubspec defines federated default packages for platforms',
    () {
      final pubspec = File(
        p.join('packages', 'nexa_http', 'pubspec.yaml'),
      ).readAsStringSync();

      expect(pubspec, contains('default_package: nexa_http_native_android'));
      expect(pubspec, contains('default_package: nexa_http_native_ios'));
      expect(pubspec, contains('default_package: nexa_http_native_macos'));
      expect(pubspec, contains('default_package: nexa_http_native_windows'));
    },
  );
}
