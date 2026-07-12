import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/checks/static_checks.dart';
import '../../scripts/verification/executor.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/planner.dart';
import '../../scripts/verification/workspace_inventory.dart';

void main() {
  test('static suite registers its required checks exactly once', () {
    final inventory = WorkspaceInventory('/workspace');
    final checks = buildStaticChecks(
      workspaceRoot: '/workspace',
      inventory: inventory,
      runCommand: (_) async {},
    );
    final catalog = VerificationCatalog(checks);

    expect(
      catalog
          .checksForSuite(VerificationSuiteId.verifyStatic)
          .map((check) => check.id.value),
      <String>[
        'generated-bindings-freshness',
        'root-contract-test',
        'rust-clippy',
        'rust-format',
        'rust-workspace-test',
        'workspace-dart-analyze',
        'workspace-dart-test',
      ],
    );
  });

  test(
    'workspace Dart analyze runs once per package with its SDK tool',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'nexa_http_static_analyze_',
      );
      addTearDown(() async {
        if (workspace.existsSync()) {
          await workspace.delete(recursive: true);
        }
      });
      final dartPackage = await _writePackage(
        workspace,
        'dart_package',
        flutter: false,
      );
      final flutterPackage = await _writePackage(
        workspace,
        'flutter_package',
        flutter: true,
      );
      final commands = <VerificationCommand>[];
      final check = workspaceDartAnalyzeCheck(
        WorkspaceInventory(workspace.path),
        (command) async => commands.add(command),
      );
      final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
      final plan = VerificationPlanner(
        catalog,
      ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

      await const VerificationExecutor().execute(plan);

      expect(
        commands
            .map(
              (command) => <Object>[
                command.workingDirectory,
                command.executable,
                command.arguments,
              ],
            )
            .toList(),
        <List<Object>>[
          <Object>[
            dartPackage.path,
            'dart',
            <String>['analyze'],
          ],
          <Object>[
            flutterPackage.path,
            'flutter',
            <String>['analyze'],
          ],
        ],
      );
    },
  );

  test('workspace Dart test skips packages without tests', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_static_test_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });
    await _writePackage(workspace, 'without_tests', flutter: false);
    final flutterPackage = await _writePackage(
      workspace,
      'with_tests',
      flutter: true,
    );
    await Directory('${flutterPackage.path}/test').create();
    final commands = <VerificationCommand>[];
    final check = workspaceDartTestCheck(
      WorkspaceInventory(workspace.path),
      (command) async => commands.add(command),
    );
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

    await const VerificationExecutor().execute(plan);

    expect(commands, hasLength(1));
    expect(commands.single.workingDirectory, flutterPackage.path);
    expect(commands.single.executable, 'flutter');
    expect(commands.single.arguments, <String>['test']);
  });

  test('Rust format check uses the workspace Cargo contract', () async {
    final commands = <VerificationCommand>[];
    final check = rustFormatCheck(
      '/workspace',
      (command) async => commands.add(command),
    );
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

    await const VerificationExecutor().execute(plan);

    expect(commands, hasLength(1));
    expect(commands.single.workingDirectory, '/workspace');
    expect(commands.single.executable, 'cargo');
    expect(commands.single.arguments, <String>[
      'fmt',
      '--all',
      '--',
      '--check',
    ]);
  });

  test('Rust clippy check denies workspace warnings', () async {
    final commands = <VerificationCommand>[];
    final check = rustClippyCheck(
      '/workspace',
      (command) async => commands.add(command),
    );
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

    await const VerificationExecutor().execute(plan);

    expect(commands.single.executable, 'cargo');
    expect(commands.single.arguments, <String>[
      'clippy',
      '--workspace',
      '--all-targets',
      '--',
      '-D',
      'warnings',
    ]);
  });

  test('Rust test check covers the Cargo workspace', () async {
    final commands = <VerificationCommand>[];
    final check = rustWorkspaceTestCheck(
      '/workspace',
      (command) async => commands.add(command),
    );
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

    await const VerificationExecutor().execute(plan);

    expect(commands.single.executable, 'cargo');
    expect(commands.single.arguments, <String>['test', '--workspace']);
  });

  test('root contract tests run outside package discovery', () async {
    final commands = <VerificationCommand>[];
    final check = rootContractTestCheck(
      '/workspace',
      (command) async => commands.add(command),
    );
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

    await const VerificationExecutor().execute(plan);

    expect(commands.single.workingDirectory, '/workspace');
    expect(commands.single.executable, 'dart');
    expect(commands.single.arguments, <String>['test']);
  });

  test(
    'generated bindings freshness regenerates then checks the source diff',
    () async {
      final commands = <VerificationCommand>[];
      final check = generatedBindingsFreshnessCheck(
        '/workspace',
        (command) async => commands.add(command),
      );
      final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
      final plan = VerificationPlanner(
        catalog,
      ).planSuite(VerificationSuiteId.verifyStatic, staticLinuxExecutionId);

      await const VerificationExecutor().execute(plan);

      expect(commands, hasLength(2));
      expect(
        commands.first.workingDirectory,
        p.join('/workspace', 'packages', 'nexa_http'),
      );
      expect(commands.first.executable, 'dart');
      expect(commands.first.arguments, <String>[
        'run',
        'ffigen',
        '--config',
        'ffigen.yaml',
      ]);
      expect(commands.last.executable, 'git');
      expect(commands.last.arguments, <String>[
        'diff',
        '--ignore-all-space',
        '--exit-code',
        '--',
        'lib/src/native_bridge/nexa_http_bindings_generated.dart',
      ]);
    },
  );
}

Future<Directory> _writePackage(
  Directory workspace,
  String name, {
  required bool flutter,
}) async {
  final directory = Directory('${workspace.path}/packages/$name');
  await directory.create(recursive: true);
  await File('${directory.path}/pubspec.yaml').writeAsString('''
name: $name
environment:
  sdk: ^3.11.0
${flutter ? 'dependencies:\n  flutter:\n    sdk: flutter\n' : ''}
''');
  return directory;
}
