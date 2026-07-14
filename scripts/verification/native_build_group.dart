import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import 'command.dart';
import 'target_matrix.dart';

Future<void> runGroupedNativeBuild({
  required String workspaceRoot,
  required IntegrationExecutionRow row,
  required String profile,
  required String outputDirectory,
  required VerificationCommandRunner runCommand,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
}) async {
  final buildScriptNames =
      row.targets.map((target) => target.buildScriptName).toSet().toList()
        ..sort();
  final bashExecutable = await resolveBashExecutable();
  for (final buildScriptName in buildScriptNames) {
    final targets = row.targets
        .where((target) => target.buildScriptName == buildScriptName)
        .map((target) => target.rustTargetTriple)
        .toList(growable: false);
    await runCommand(
      VerificationCommand(
        executable: bashExecutable,
        arguments: <String>[
          p.join(workspaceRoot, 'scripts', buildScriptName),
          profile,
          '--output-dir',
          outputDirectory,
          for (final target in targets) ...<String>['--target', target],
        ],
        workingDirectory: workspaceRoot,
      ),
    );
  }
}
