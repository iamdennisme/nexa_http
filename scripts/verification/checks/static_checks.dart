import '../command.dart';
import '../model.dart';
import '../workspace_inventory.dart';
import 'package:path/path.dart' as p;

export '../command.dart';

const staticLinuxExecutionId = VerificationExecutionId('static-linux');
const _workspaceInventoryResourceKey = VerificationResourceKey(
  'workspace-inventory',
);

List<VerificationCheckDefinition> buildStaticChecks({
  required String workspaceRoot,
  required WorkspaceInventory inventory,
  required VerificationCommandRunner runCommand,
}) {
  return <VerificationCheckDefinition>[
    generatedBindingsFreshnessCheck(workspaceRoot, runCommand),
    rootContractTestCheck(workspaceRoot, runCommand),
    workspaceDartAnalyzeCheck(inventory, runCommand),
    workspaceDartTestCheck(inventory, runCommand),
    rustFormatCheck(workspaceRoot, runCommand),
    rustClippyCheck(workspaceRoot, runCommand),
    rustWorkspaceTestCheck(workspaceRoot, runCommand),
  ];
}

VerificationCheckDefinition generatedBindingsFreshnessCheck(
  String workspaceRoot,
  VerificationCommandRunner runCommand,
) {
  final packageRoot = p.join(workspaceRoot, 'packages', 'nexa_http');
  return VerificationCheckDefinition(
    id: const VerificationCheckId('generated-bindings-freshness'),
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
    supportedExecutions: const <VerificationExecutionId>[
      staticLinuxExecutionId,
    ],
    action: (_) async {
      await runCommand(
        VerificationCommand(
          executable: 'dart',
          arguments: const <String>['run', 'ffigen', '--config', 'ffigen.yaml'],
          workingDirectory: packageRoot,
        ),
      );
      await runCommand(
        VerificationCommand(
          executable: 'git',
          arguments: const <String>[
            'diff',
            '--ignore-all-space',
            '--exit-code',
            '--',
            'lib/src/native_bridge/nexa_http_bindings_generated.dart',
          ],
          workingDirectory: packageRoot,
        ),
      );
    },
  );
}

VerificationCheckDefinition rootContractTestCheck(
  String workspaceRoot,
  VerificationCommandRunner runCommand,
) {
  return _commandCheck(
    id: const VerificationCheckId('root-contract-test'),
    command: VerificationCommand(
      executable: 'dart',
      arguments: const <String>['test'],
      workingDirectory: workspaceRoot,
    ),
    runCommand: runCommand,
  );
}

VerificationCheckDefinition workspaceDartAnalyzeCheck(
  WorkspaceInventory inventory,
  VerificationCommandRunner runCommand,
) {
  return _workspacePackageCommandCheck(
    id: const VerificationCheckId('workspace-dart-analyze'),
    arguments: const <String>['analyze'],
    inventory: inventory,
    runCommand: runCommand,
  );
}

VerificationCheckDefinition workspaceDartTestCheck(
  WorkspaceInventory inventory,
  VerificationCommandRunner runCommand,
) {
  return _workspacePackageCommandCheck(
    id: const VerificationCheckId('workspace-dart-test'),
    arguments: const <String>['test'],
    inventory: inventory,
    runCommand: runCommand,
    onlyPackagesWithTests: true,
  );
}

VerificationCheckDefinition rustFormatCheck(
  String workspaceRoot,
  VerificationCommandRunner runCommand,
) {
  return _commandCheck(
    id: const VerificationCheckId('rust-format'),
    command: VerificationCommand(
      executable: 'cargo',
      arguments: const <String>['fmt', '--all', '--', '--check'],
      workingDirectory: workspaceRoot,
    ),
    runCommand: runCommand,
  );
}

VerificationCheckDefinition rustClippyCheck(
  String workspaceRoot,
  VerificationCommandRunner runCommand,
) {
  return _commandCheck(
    id: const VerificationCheckId('rust-clippy'),
    command: VerificationCommand(
      executable: 'cargo',
      arguments: const <String>[
        'clippy',
        '--workspace',
        '--all-targets',
        '--',
        '-D',
        'warnings',
      ],
      workingDirectory: workspaceRoot,
    ),
    runCommand: runCommand,
  );
}

VerificationCheckDefinition rustWorkspaceTestCheck(
  String workspaceRoot,
  VerificationCommandRunner runCommand,
) {
  return _commandCheck(
    id: const VerificationCheckId('rust-workspace-test'),
    command: VerificationCommand(
      executable: 'cargo',
      arguments: const <String>['test', '--workspace'],
      workingDirectory: workspaceRoot,
    ),
    runCommand: runCommand,
  );
}

VerificationCheckDefinition _commandCheck({
  required VerificationCheckId id,
  required VerificationCommand command,
  required VerificationCommandRunner runCommand,
}) {
  return VerificationCheckDefinition(
    id: id,
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
    supportedExecutions: const <VerificationExecutionId>[
      staticLinuxExecutionId,
    ],
    action: (_) => runCommand(command),
  );
}

VerificationCheckDefinition _workspacePackageCommandCheck({
  required VerificationCheckId id,
  required List<String> arguments,
  required WorkspaceInventory inventory,
  required VerificationCommandRunner runCommand,
  bool onlyPackagesWithTests = false,
}) {
  return VerificationCheckDefinition(
    id: id,
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
    supportedExecutions: const <VerificationExecutionId>[
      staticLinuxExecutionId,
    ],
    action: (context) async {
      final packages = await context.memoize(
        _workspaceInventoryResourceKey,
        inventory.packages,
      );
      for (final package in packages) {
        if (onlyPackagesWithTests && !package.hasTests) {
          continue;
        }
        await runCommand(
          VerificationCommand(
            executable: package.tool == WorkspacePackageTool.flutter
                ? 'flutter'
                : 'dart',
            arguments: arguments,
            workingDirectory: package.directory.path,
          ),
        );
      }
    },
  );
}
