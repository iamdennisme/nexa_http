import 'dart:io';

import 'verification/command.dart';
import 'verification/workspace_inventory.dart';

Future<void> bootstrapWorkspace({
  required String workspaceRoot,
  required VerificationCommandRunner runCommand,
}) async {
  final packages = await WorkspaceInventory(workspaceRoot).packages();
  for (final package in packages) {
    await runCommand(
      VerificationCommand(
        executable: package.tool == WorkspacePackageTool.flutter
            ? 'flutter'
            : 'dart',
        arguments: const <String>['pub', 'get'],
        workingDirectory: package.directory.path,
      ),
    );
  }
}

Future<void> runWorkspaceBootstrap(String workspaceRoot) {
  return bootstrapWorkspace(
    workspaceRoot: workspaceRoot,
    runCommand: (command) => runVerificationCommand(
      command,
      onStdoutLine: stdout.writeln,
      onStderrLine: stderr.writeln,
    ),
  );
}
