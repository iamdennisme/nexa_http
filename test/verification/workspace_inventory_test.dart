import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/verification/workspace_inventory.dart';

void main() {
  test('discovers workspace packages once per inventory', () async {
    var discoveryRuns = 0;
    final inventory = WorkspaceInventory(
      '/workspace',
      discoverPackages: (workspaceRoot) async {
        discoveryRuns += 1;
        return <Directory>[Directory('$workspaceRoot/packages/nexa_http')];
      },
    );

    final first = await inventory.packageDirectories();
    final second = await inventory.packageDirectories();

    expect(discoveryRuns, 1);
    expect(identical(first, second), isTrue);
  });

  test('classifies Dart and Flutter packages from one inventory', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_inventory_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });
    final dartPackage = Directory('${workspace.path}/packages/dart_package');
    final flutterPackage = Directory(
      '${workspace.path}/packages/flutter_package',
    );
    await dartPackage.create(recursive: true);
    await flutterPackage.create(recursive: true);
    await File('${dartPackage.path}/pubspec.yaml').writeAsString('''
name: dart_package
environment:
  sdk: ^3.11.0
''');
    await File('${flutterPackage.path}/pubspec.yaml').writeAsString('''
name: flutter_package
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''');
    await Directory('${flutterPackage.path}/test').create();

    final packages = await WorkspaceInventory(workspace.path).packages();

    expect(
      packages
          .map(
            (package) => <Object>[
              package.relativePath,
              package.tool.name,
              package.hasTests,
            ],
          )
          .toList(),
      <List<Object>>[
        <Object>['packages/dart_package', 'dart', false],
        <Object>['packages/flutter_package', 'flutter', true],
      ],
    );
  });
}
