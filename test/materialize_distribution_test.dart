import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/materialize_distribution.dart';

void main() {
  test('materializes selected packages and their local path dependencies', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'rust_net_materialize_test_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await _writeFile(
      workspace,
      'pubspec.yaml',
      'name: test_workspace\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/rust_net/pubspec.yaml',
      'name: rust_net\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(workspace, 'packages/rust_net/lib/rust_net.dart', 'library rust_net;\n');
    await _writeFile(
      workspace,
      'packages/rust_net_core/pubspec.yaml',
      'name: rust_net_core\nenvironment:\n  sdk: ^3.11.0\ndependencies:\n  rust_net:\n    path: ../rust_net\n',
    );
    await _writeFile(workspace, 'packages/rust_net_core/lib/rust_net_core.dart', 'export \'package:rust_net/rust_net.dart\';\n');
    await _writeFile(
      workspace,
      'packages/rust_net_core/pubspec.lock',
      'should_not_be_copied',
    );
    await _writeFile(
      workspace,
      'packages/rust_net_core/.dart_tool/package_config.json',
      '{}',
    );

    final outputDir = Directory(p.join(workspace.path, '.dist', 'workspace'));

    await materializeDistributionWorkspace(
      workspaceRoot: workspace.path,
      outputDirectory: outputDir.path,
      requestedPackages: {'rust_net_core'},
    );

    expect(
      File(p.join(outputDir.path, 'pubspec.yaml')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'rust_net_core', 'pubspec.yaml'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'rust_net', 'pubspec.yaml'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'rust_net_core', 'pubspec.lock'))
          .existsSync(),
      isFalse,
    );
    expect(
      File(
        p.join(
          outputDir.path,
          'packages',
          'rust_net_core',
          '.dart_tool',
          'package_config.json',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('fails when a selected carrier package has missing native artifacts', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'rust_net_materialize_missing_artifacts_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await _writeFile(
      workspace,
      'pubspec.yaml',
      'name: test_workspace\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(
      workspace,
      'packages/rust_net_native_macos/pubspec.yaml',
      'name: rust_net_native_macos\nenvironment:\n  sdk: ^3.11.0\n',
    );

    final outputDir = Directory(p.join(workspace.path, '.dist', 'workspace'));

    await expectLater(
      () => materializeDistributionWorkspace(
        workspaceRoot: workspace.path,
        outputDirectory: outputDir.path,
        requestedPackages: {'rust_net_native_macos'},
      ),
      throwsA(
        isA<StateError>().having(
          (error) => '$error',
          'message',
          contains('Missing required artifact'),
        ),
      ),
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
