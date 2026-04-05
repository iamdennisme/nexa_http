import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
  test('parses the simplified workspace verification command set', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_verification_commands_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

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
          'dist/native-assets/nexa_http-native-windows-x64.dll\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_native_internal/pubspec.yaml',
      'name: nexa_http_native_internal\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_native_internal/test/internal_test.dart',
      'void main() {}\n',
    );
    await _writeFile(
      workspace,
      'app/demo/pubspec.yaml',
      'name: nexa_http_demo\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await _writeFile(
      workspace,
      'app/demo/test/widget_test.dart',
      'void main() {}\n',
    );

    final commands = <String>[];

    await verifyArtifacts(
      workspace.path,
      runPackageCommand: (packageDir, executable, arguments, {environment}) async {
        commands.add('${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );
    await verifyDemo(
      workspace.path,
      runPackageCommand: (packageDir, executable, arguments, {environment}) async {
        commands.add('${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );
    await verifyExternalConsumer(
      workspace.path,
      runPackageCommand: (packageDir, executable, arguments, {environment}) async {
        commands.add('${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(commands, isNotEmpty);
  });

  test('verify-demo schedules host-specific builds when platform projects exist', () async {
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
      'app/demo/pubspec.yaml',
      'name: nexa_http_demo\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await _writeFile(
      workspace,
      'app/demo/test/widget_test.dart',
      'void main() {}\n',
    );
    await _writeFile(workspace, 'app/demo/macos/.keep', '');
    await _writeFile(workspace, 'app/demo/ios/.keep', '');

    final commands = <String>[];

    await verifyDemo(
      workspace.path,
      hostPlatform: WorkspaceHostPlatform.macos,
      runPackageCommand: (packageDir, executable, arguments, {environment}) async {
        commands.add('${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(
      commands,
      containsAll(<String>[
        'demo:flutter pub get',
        'demo:flutter test',
        'demo:flutter build macos --debug',
        'demo:flutter build ios --simulator --debug --no-codesign',
      ]),
    );
  });

  test('ios simulator build failures can be classified as missing local prerequisites', () {
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
      'app/demo/pubspec.yaml',
      'name: nexa_http_demo\nenvironment:\n  sdk: ^3.11.0\n',
    );

    final packages = discoverWorkspacePackageDirs(workspace.path);

    expect(
      packages
          .map((directory) => p.relative(directory.path, from: workspace.path))
          .toList(),
      <String>[
        'app/demo',
        'packages/nexa_http',
        'packages/nexa_http_native_ios',
      ],
    );
  });
}

Future<void> _writeFile(
  Directory root,
  String relativePath,
  String contents,
) async {
  final file = File(p.join(root.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
