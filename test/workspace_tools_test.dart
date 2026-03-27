import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/workspace_tools.dart';

void main() {
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
      runPackageCommand: (packageDir, executable, arguments) async {
        commands.add('${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
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

    await _writeFile(
      workspace,
      'packages/nexa_http/pubspec.yaml',
      'name: nexa_http\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(workspace, 'packages/nexa_http/test/sample_test.dart', 'void main() {}\n');
    await _writeFile(
      workspace,
      'packages/nexa_http_native_linux/pubspec.yaml',
      'name: nexa_http_native_linux\nflutter:\n  plugin:\n    platforms:\n      linux:\n        pluginClass: NexaHttpNativeLinuxPlugin\n',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http/example/pubspec.yaml',
      'name: nexa_http_example\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );

    final commands = <String>[];

    await verifyWorkspacePackages(
      workspace.path,
      runPackageCommand: (packageDir, executable, arguments) async {
        commands.add('${p.basename(packageDir.path)}:$executable ${arguments.join(' ')}');
      },
    );

    expect(
      commands,
      <String>[
        'nexa_http:dart analyze',
        'nexa_http:dart test',
        'example:flutter analyze',
        'nexa_http_native_linux:flutter analyze',
      ],
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
