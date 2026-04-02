import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test('parses the expanded workspace verification command set', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_verification_commands_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await _seedReleaseConsumerFixture(workspace);
    await _writeFile(
      workspace,
      '.github/workflows/release-native-assets.yml',
      'dist/native-assets/nexa_http-native-android-arm64-v8a.so\n'
          'dist/native-assets/nexa_http-native-android-armeabi-v7a.so\n'
          'dist/native-assets/nexa_http-native-android-x86_64.so\n'
          'dist/native-assets/nexa_http-native-ios-arm64.dylib\n'
          'dist/native-assets/nexa_http-native-ios-sim-arm64.dylib\n'
          'dist/native-assets/nexa_http-native-ios-sim-x64.dylib\n'
          'dist/native-assets/nexa_http-native-macos-arm64.dylib\n'
          'dist/native-assets/nexa_http-native-macos-x64.dylib\n'
          'dist/native-assets/nexa_http-native-windows-x64.dll\n'
          'x86_64-pc-windows-msvc\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_distribution/test/nexa_http_native_release_manifest_test.dart',
      'void main() {}\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/test/widget_test.dart',
      'void main() {}\n',
    );

    final commands = <String>[];

    await verifyArtifacts(
      workspace.path,
      runPackageCommand:
          (packageDir, executable, arguments, {environment}) async {
        commands.add(
            '${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );
    await verifyDemo(
      workspace.path,
      runPackageCommand:
          (packageDir, executable, arguments, {environment}) async {
        commands.add(
            '${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );
    await verifyExternalConsumer(
      workspace.path,
      runPackageCommand:
          (packageDir, executable, arguments, {environment}) async {
        commands.add(
            '${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(commands, isNotEmpty);
  });

  test(
      'verify-demo schedules host-specific builds when platform projects exist',
      () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_verify_demo_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/test/widget_test.dart',
      'void main() {}\n',
    );
    await _writeFile(workspace, 'packages/nexa_http/example/macos/.keep', '');
    await _writeFile(workspace, 'packages/nexa_http/example/ios/.keep', '');

    final commands = <String>[];

    await verifyDemo(
      workspace.path,
      hostPlatform: WorkspaceHostPlatform.macos,
      runPackageCommand:
          (packageDir, executable, arguments, {environment}) async {
        commands.add(
            '${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(
      commands,
      containsAll(<String>[
        'example:flutter pub get',
        'example:flutter test',
        'example:flutter build macos --debug',
        'example:flutter build ios --simulator --debug --no-codesign',
      ]),
    );
  });

  test(
      'ios simulator build failures can be classified as missing local prerequisites',
      () {
    final error = ProcessException(
      'flutter',
      const <String>['build', 'ios', '--simulator', '--debug', '--no-codesign'],
      'Unable to find a destination matching the provided destination specifier:\n'
          '{ generic:1, platform:iOS Simulator }\n'
          'iOS 26.2 is not installed.',
      1,
    );

    expect(isSkippableDemoBuildPrerequisiteFailure(error), isTrue);
  });

  test(
      'reads aligned release-train versions and ignores packages/nexa_http/example',
      () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_release_train_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    for (final packageName in releaseTrainPackageNames) {
      await _writeFile(
        workspace,
        'packages/$packageName/pubspec.yaml',
        'name: $packageName\nversion: 1.2.3\nenvironment:\n  sdk: ^3.11.0\n',
      );
    }
    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\nversion: 9.9.9\nenvironment:\n  sdk: ^3.11.0\n',
    );

    final versions = readReleaseTrainPackageVersions(workspace.path);

    expect(versions.keys, orderedEquals(releaseTrainPackageNames));
    expect(versions.values.toSet(), <String>{'1.2.3'});
  });

  test('fails when a release-train package version drifts', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_release_drift_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    for (final packageName in releaseTrainPackageNames) {
      final version = packageName == 'nexa_http_runtime' ? '1.2.4' : '1.2.3';
      await _writeFile(
        workspace,
        'packages/$packageName/pubspec.yaml',
        'name: $packageName\nversion: $version\nenvironment:\n  sdk: ^3.11.0\n',
      );
    }

    expect(
      () => verifyAlignedReleaseTrainVersions(workspace.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('nexa_http_runtime=1.2.4'),
        ),
      ),
    );
  });

  test('fails when a release tag does not match aligned package versions',
      () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_release_tag_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    for (final packageName in releaseTrainPackageNames) {
      await _writeFile(
        workspace,
        'packages/$packageName/pubspec.yaml',
        'name: $packageName\nversion: 1.2.3\nenvironment:\n  sdk: ^3.11.0\n',
      );
    }

    expect(
      () =>
          verifyAlignedReleaseTrainVersions(workspace.path, tagName: 'v1.2.4'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
              'Release tag v1.2.4 does not match aligned package version 1.2.3'),
        ),
      ),
    );
  });

  test('discovers workspace packages recursively under packages/', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_tools_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await _writeFile(
      workspace,
      'packages/nexa_http/pubspec.yaml',
      'name: nexa_http\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_native_ios/pubspec.yaml',
      'name: nexa_http_native_ios\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\nenvironment:\n  sdk: ^3.11.0\n',
    );

    final packages = discoverWorkspacePackageDirs(workspace.path);

    expect(
      packages
          .map((directory) => p.relative(directory.path, from: workspace.path))
          .toList(),
      <String>[
        'packages/nexa_http',
        'packages/nexa_http/example',
        'packages/nexa_http_native_ios',
      ],
    );
  });

  test('runs pub get across discovered packages', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_bootstrap_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await _writeFile(
      workspace,
      'packages/nexa_http/pubspec.yaml',
      'name: nexa_http\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_native_macos/pubspec.yaml',
      'name: nexa_http_native_macos\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\nflutter:\n  uses-material-design: true\n',
    );

    final commands = <String>[];

    await bootstrapWorkspacePackages(
      workspace.path,
      runPackageCommand:
          (packageDir, executable, arguments, {environment}) async {
        commands.add(
            '${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(
      commands,
      <String>[
        'nexa_http:dart pub get',
        'example:flutter pub get',
        'nexa_http_native_macos:dart pub get',
      ],
    );
  });

  test('runs analyze and test for each discovered package', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_verify_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    for (final packageName in releaseTrainPackageNames) {
      final usesFlutter = packageName.startsWith('nexa_http_native_');
      await _writeFile(
        workspace,
        'packages/$packageName/pubspec.yaml',
        usesFlutter
            ? 'name: $packageName\nversion: 1.2.3\nflutter:\n  plugin:\n    platforms:\n      ${packageName.replaceFirst('nexa_http_native_', '')}:\n        dartPluginClass: PlaceholderPlugin\n'
            : 'name: $packageName\nversion: 1.2.3\nenvironment:\n  sdk: ^3.11.0\n',
      );
    }
    await _seedReleaseConsumerFixture(workspace, includePubspecs: false);
    await _writeFile(
      workspace,
      '.github/workflows/release-native-assets.yml',
      'dist/native-assets/nexa_http-native-android-arm64-v8a.so\n'
          'dist/native-assets/nexa_http-native-android-armeabi-v7a.so\n'
          'dist/native-assets/nexa_http-native-android-x86_64.so\n'
          'dist/native-assets/nexa_http-native-ios-arm64.dylib\n'
          'dist/native-assets/nexa_http-native-ios-sim-arm64.dylib\n'
          'dist/native-assets/nexa_http-native-ios-sim-x64.dylib\n'
          'dist/native-assets/nexa_http-native-macos-arm64.dylib\n'
          'dist/native-assets/nexa_http-native-macos-x64.dylib\n'
          'dist/native-assets/nexa_http-native-windows-x64.dll\n'
          'x86_64-pc-windows-msvc\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_distribution/test/nexa_http_native_release_manifest_test.dart',
      'void main() {}\n',
    );
    await _writeFile(workspace, 'packages/nexa_http/test/sample_test.dart',
        'void main() {}\n');
    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/test/widget_test.dart',
      'void main() {}\n',
    );

    final commands = <String>[];

    await verifyWorkspacePackages(
      workspace.path,
      runPackageCommand:
          (packageDir, executable, arguments, {environment}) async {
        commands.add(
            '${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(
      commands,
      containsAll(<Object>[
        'nexa_http_distribution:dart test test/nexa_http_native_release_manifest_test.dart',
        'example:flutter pub get',
        'example:flutter test',
        contains('consumer:flutter create'),
        'consumer:flutter pub get',
        'nexa_http:dart analyze',
        'nexa_http:dart test',
        'example:flutter analyze',
        'example:flutter test',
        'nexa_http_distribution:dart analyze',
        'nexa_http_distribution:dart test',
        'nexa_http_native_android:flutter analyze',
        'nexa_http_native_ios:flutter analyze',
        'nexa_http_native_macos:flutter analyze',
        'nexa_http_native_windows:flutter analyze',
        'nexa_http_runtime:dart analyze',
      ]),
    );
  });
}

Future<void> _writeFile(
  Directory workspace,
  String relativePath,
  String contents,
) async {
  final file = File(p.join(workspace.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

Future<void> _seedReleaseConsumerFixture(
  Directory workspace, {
  bool includePubspecs = true,
}) async {
  if (includePubspecs) {
    for (final packageName in releaseTrainPackageNames) {
      final usesFlutter = packageName == 'nexa_http' ||
          packageName.startsWith('nexa_http_native_');
      await _writeFile(
        workspace,
        'packages/$packageName/pubspec.yaml',
        usesFlutter
            ? 'name: $packageName\nversion: 1.2.3\nflutter:\n  plugin:\n    platforms:\n      macos:\n        dartPluginClass: PlaceholderPlugin\n'
            : 'name: $packageName\nversion: 1.2.3\nenvironment:\n  sdk: ^3.11.0\n',
      );
    }
  }

  await _writeFile(
    workspace,
    'packages/nexa_http_native_macos/macos/Libraries/libnexa_http_native.dylib',
    'fixture-macos-binary',
  );
}
