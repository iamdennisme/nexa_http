import 'package:path/path.dart' as p;

import '../command.dart';
import '../model.dart';
import '../target_matrix.dart';

export '../command.dart';

typedef VerificationExecutionCheckRunner =
    Future<void> Function(VerificationExecutionId executionId);

List<VerificationCheckDefinition> buildIntegrationChecks({
  required String workspaceRoot,
  required List<IntegrationExecutionRow> executionRows,
  required VerificationCommandRunner runCommand,
  required VerificationExecutionCheckRunner verifyAbi,
  required VerificationExecutionCheckRunner verifyDevelopmentPath,
  required VerificationExecutionCheckRunner verifyExternalConsumer,
}) {
  return <VerificationCheckDefinition>[
    nativeBuildCheck(workspaceRoot, executionRows, runCommand),
    nativeAbiCheck(executionRows, verifyAbi),
    developmentPathCheck(executionRows, verifyDevelopmentPath),
    externalConsumerCheck(executionRows, verifyExternalConsumer),
  ];
}

VerificationCheckDefinition nativeBuildCheck(
  String workspaceRoot,
  List<IntegrationExecutionRow> executionRows,
  VerificationCommandRunner runCommand,
) {
  return VerificationCheckDefinition(
    id: const VerificationCheckId('native-build'),
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    action: (context) async {
      final row = executionRows.singleWhere(
        (candidate) => candidate.executionId == context.executionId,
      );
      final buildScriptNames =
          row.targets.map((target) => target.buildScriptName).toSet().toList()
            ..sort();
      for (final buildScriptName in buildScriptNames) {
        await runCommand(
          VerificationCommand(
            executable: 'bash',
            arguments: <String>[
              p.join(workspaceRoot, 'scripts', buildScriptName),
              'debug',
            ],
            workingDirectory: workspaceRoot,
          ),
        );
      }
    },
  );
}

VerificationCheckDefinition nativeAbiCheck(
  List<IntegrationExecutionRow> executionRows,
  VerificationExecutionCheckRunner verifyAbi,
) {
  return _dependentExecutionCheck(
    id: const VerificationCheckId('native-abi'),
    executionRows: executionRows,
    runCheck: verifyAbi,
  );
}

VerificationCheckDefinition developmentPathCheck(
  List<IntegrationExecutionRow> executionRows,
  VerificationExecutionCheckRunner verifyDevelopmentPath,
) {
  return _dependentExecutionCheck(
    id: const VerificationCheckId('development-path'),
    executionRows: executionRows,
    runCheck: verifyDevelopmentPath,
  );
}

VerificationCheckDefinition externalConsumerCheck(
  List<IntegrationExecutionRow> executionRows,
  VerificationExecutionCheckRunner verifyExternalConsumer,
) {
  return _dependentExecutionCheck(
    id: const VerificationCheckId('external-consumer'),
    executionRows: executionRows,
    runCheck: verifyExternalConsumer,
  );
}

VerificationCheckDefinition _dependentExecutionCheck({
  required VerificationCheckId id,
  required List<IntegrationExecutionRow> executionRows,
  required VerificationExecutionCheckRunner runCheck,
}) {
  return VerificationCheckDefinition(
    id: id,
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    dependencies: const <VerificationCheckId>[
      VerificationCheckId('native-build'),
    ],
    action: (context) => runCheck(context.executionId),
  );
}
