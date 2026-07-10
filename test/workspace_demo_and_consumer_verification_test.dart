import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test('workspace tools expose simplified verification commands', () {
    expect(
      workspaceVerificationCommands,
      contains('verify-artifact-consistency'),
    );
    expect(workspaceVerificationCommands, contains('verify-native-abi'));
    expect(workspaceVerificationCommands, contains('verify-development-path'));
    expect(workspaceVerificationCommands, contains('verify-external-consumer'));
    expect(workspaceVerificationCommands, contains('verify-release-consumer'));
    expect(
      workspaceVerificationCommands,
      isNot(contains('check-release-train')),
    );
  });

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
    expect(workflow, contains('verify-release-consumer'));
  });

  test(
    'pr CI workflow blocks on development-path and artifact-consistency verification',
    () {
      final workflow = File(
        p.join('.github', 'workflows', 'ci.yml'),
      ).readAsStringSync();

      expect(workflow, contains('ubuntu-latest'));
      expect(workflow, contains('macos-14'));
      expect(workflow, contains('windows-latest'));
      expect(workflow, contains('verify-artifact-consistency'));
      expect(RegExp('verify-native-abi').allMatches(workflow), hasLength(3));
      expect(workflow, contains('dart run ffigen --config ffigen.yaml'));
      expect(
        workflow,
        contains('dart test test/native_ffi_abi_contract_test.dart'),
      );
      expect(workflow, contains('test/native_abi_verifier_test.dart'));
      expect(
        workflow,
        contains(
          'git diff --ignore-all-space --exit-code -- lib/nexa_http_bindings_generated.dart',
        ),
      );
      expect(workflow, contains('verify-development-path'));
      expect(workflow, contains('verify-external-consumer'));
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

      final iosHook = File(
        p.join('packages', 'nexa_http_native_ios', 'hook', 'build.dart'),
      ).readAsStringSync();
      expect(
        iosHook,
        contains("import '../lib/src/nexa_http_native_ios_asset_bundle.dart';"),
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

      final windowsHook = File(
        p.join('packages', 'nexa_http_native_windows', 'hook', 'build.dart'),
      ).readAsStringSync();
      expect(
        windowsHook,
        contains(
          "import '../lib/src/nexa_http_native_windows_asset_bundle.dart';",
        ),
      );
    },
  );

  test('example README documents all supported platform run targets', () {
    final readme = File(p.join('app', 'demo', 'README.md')).readAsStringSync();

    expect(readme, contains('flutter run -d macos'));
    expect(readme, contains('flutter run -d windows'));
    expect(readme, contains('flutter run -d android'));
    expect(readme, contains('flutter run -d ios'));
  });

  test(
    'official demo contains platform projects for every supported demo target',
    () {
      expect(Directory(p.join('app', 'demo', 'android')).existsSync(), isTrue);
      expect(Directory(p.join('app', 'demo', 'ios')).existsSync(), isTrue);
      expect(Directory(p.join('app', 'demo', 'macos')).existsSync(), isTrue);
      expect(Directory(p.join('app', 'demo', 'windows')).existsSync(), isTrue);
    },
  );

  test(
    'public package README separates API surface from platform dependencies',
    () {
      final readme = File(
        p.join('packages', 'nexa_http', 'README.md'),
      ).readAsStringSync();

      expect(readme, isNot(contains('nexa_http_runtime:')));
      expect(readme, isNot(contains('nexa_http_distribution:')));
      expect(readme, contains('nexa_http:'));
      expect(readme, contains('nexa_http_native_macos:'));
      expect(readme, contains('git:'));
    },
  );

  test('official demo app layer declares public API and platform packages', () {
    final pubspec = File(
      p.join('app', 'demo', 'pubspec.yaml'),
    ).readAsStringSync();

    expect(pubspec, contains('nexa_http:'));
    expect(pubspec, contains('nexa_http_native_android:'));
    expect(pubspec, contains('nexa_http_native_ios:'));
    expect(pubspec, contains('nexa_http_native_macos:'));
    expect(pubspec, contains('nexa_http_native_windows:'));
    expect(pubspec, isNot(contains('nexa_http_native_internal:')));
  });

  test('external consumer fixture declares the host platform package', () {
    final macosPubspec = buildExternalConsumerPubspecForHost(
      'https://example.invalid/repo.git',
      WorkspaceHostPlatform.macos,
      ref: 'v0.0.3',
    );
    expect(macosPubspec, contains('nexa_http:'));
    expect(macosPubspec, contains('nexa_http_native_macos:'));
    expect(macosPubspec, contains('ref: v0.0.3'));
    expect(macosPubspec, isNot(contains('nexa_http_native_windows:')));
    expect(macosPubspec, isNot(contains('nexa_http_native_internal:')));

    final macosSnapshotPubspec = buildExternalConsumerPubspecForHost(
      'https://example.invalid/repo.git',
      WorkspaceHostPlatform.macos,
      includeRef: false,
    );
    expect(macosSnapshotPubspec, isNot(contains('ref:')));

    final windowsPubspec = buildExternalConsumerPubspecForHost(
      'https://example.invalid/repo.git',
      WorkspaceHostPlatform.windows,
      ref: 'v0.0.3',
    );
    expect(windowsPubspec, contains('nexa_http:'));
    expect(windowsPubspec, contains('nexa_http_native_windows:'));
    expect(windowsPubspec, contains('ref: v0.0.3'));
    expect(windowsPubspec, isNot(contains('nexa_http_native_macos:')));

    final androidPubspec = buildExternalConsumerPubspecForHost(
      'https://example.invalid/repo.git',
      WorkspaceHostPlatform.linux,
      ref: 'v0.0.3',
    );
    expect(androidPubspec, contains('nexa_http:'));
    expect(androidPubspec, contains('nexa_http_native_android:'));
  });

  test('external consumer fixture imports and compiles the public SDK API', () {
    final mainDart = buildExternalConsumerMainDart();

    expect(mainDart, contains("import 'package:nexa_http/nexa_http.dart';"));
    expect(mainDart, isNot(contains('package:nexa_http_native_')));
    expect(mainDart, contains('NexaHttpClientBuilder()'));
    expect(mainDart, contains('RequestBuilder()'));
  });

  test('nexa_http pubspec does not hide platform package selection', () {
    final pubspec = File(
      p.join('packages', 'nexa_http', 'pubspec.yaml'),
    ).readAsStringSync();

    expect(pubspec, isNot(contains('nexa_http_native_android:')));
    expect(pubspec, isNot(contains('nexa_http_native_ios:')));
    expect(pubspec, isNot(contains('nexa_http_native_macos:')));
    expect(pubspec, isNot(contains('nexa_http_native_windows:')));
    expect(
      pubspec,
      isNot(contains('default_package: nexa_http_native_android')),
    );
    expect(pubspec, isNot(contains('default_package: nexa_http_native_ios')));
    expect(pubspec, isNot(contains('default_package: nexa_http_native_macos')));
    expect(
      pubspec,
      isNot(contains('default_package: nexa_http_native_windows')),
    );
  });
}
