import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/materialize_distribution.dart';

void main() {
  test('materializes selected packages and their local path dependencies', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_materialize_test_',
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
      'packages/nexa_http/pubspec.yaml',
      'name: nexa_http\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await _writeFile(workspace, 'packages/nexa_http/lib/nexa_http.dart', 'library nexa_http;\n');
    await _writeFile(
      workspace,
      'packages/nexa_http_native_macos/pubspec.yaml',
      'name: nexa_http_native_macos\nenvironment:\n  sdk: ^3.11.0\ndependencies:\n  nexa_http:\n    path: ../nexa_http\n',
    );
    await _writeFile(workspace, 'packages/nexa_http_native_macos/lib/nexa_http_native_macos.dart', 'library nexa_http_native_macos;\n');
    await _writeFile(
      workspace,
      'packages/nexa_http_native_macos/pubspec.lock',
      'should_not_be_copied',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_native_macos/.dart_tool/package_config.json',
      '{}',
    );
    await _writeFile(
      workspace,
      'packages/nexa_http_native_macos/macos/Libraries/libnexa_http_native.dylib',
      'binary',
    );

    final outputDir = Directory(p.join(workspace.path, '.dist', 'workspace'));

    await materializeDistributionWorkspace(
      workspaceRoot: workspace.path,
      outputDirectory: outputDir.path,
      requestedPackages: {'nexa_http_native_macos'},
    );

    expect(
      File(p.join(outputDir.path, 'pubspec.yaml')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'rust_net_core', 'pubspec.yaml'))
          .existsSync(),
      isFalse,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'nexa_http_native_macos', 'pubspec.yaml'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'nexa_http', 'pubspec.yaml'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(outputDir.path, 'packages', 'nexa_http_native_macos', 'pubspec.lock'))
          .existsSync(),
      isFalse,
    );
    expect(
      File(
        p.join(
          outputDir.path,
          'packages',
          'nexa_http_native_macos',
          '.dart_tool',
          'package_config.json',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('fails when a selected carrier package has missing native artifacts', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_materialize_missing_artifacts_',
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
      'packages/nexa_http_native_macos/pubspec.yaml',
      'name: nexa_http_native_macos\nenvironment:\n  sdk: ^3.11.0\n',
    );

    final outputDir = Directory(p.join(workspace.path, '.dist', 'workspace'));

    await expectLater(
      () => materializeDistributionWorkspace(
        workspaceRoot: workspace.path,
        outputDirectory: outputDir.path,
        requestedPackages: {'nexa_http_native_macos'},
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
