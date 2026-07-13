import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import '../../native_payload_identity.dart';
import '../command.dart';
import '../model.dart';
import '../report.dart';
import '../target_matrix.dart';

export '../command.dart';

typedef VerificationExecutionCheckRunner =
    Future<void> Function(VerificationExecutionId executionId);

typedef VerificationNativeAbiCheckRunner =
    Future<void> Function(
      List<VerifiedNativeArtifactIdentity> preparedArtifactIdentities,
    );

typedef VerificationExternalConsumerCheckRunner =
    Future<void> Function(
      VerificationExecutionId executionId,
      List<VerifiedNativeArtifactIdentity> preparedArtifactIdentities,
    );

typedef VerificationArtifactUniquenessCheckRunner =
    Future<List<VerificationRuntimePayloadProof>> Function(
      VerificationExecutionId executionId,
    );
typedef VerificationNativePayloadIdentityDigester =
    Future<String> Function(File file, {required String platform});

List<VerificationCheckDefinition> buildIntegrationChecks({
  required String workspaceRoot,
  required List<IntegrationExecutionRow> executionRows,
  required VerificationCommandRunner runCommand,
  required VerificationNativeAbiCheckRunner verifyAbi,
  required VerificationExecutionCheckRunner verifyDevelopmentPath,
  required VerificationExternalConsumerCheckRunner verifyExternalConsumer,
  required VerificationArtifactUniquenessCheckRunner verifyArtifactUniqueness,
  VerificationNativePayloadIdentityDigester identityDigest =
      nexaHttpNativePayloadIdentitySha256,
}) {
  return <VerificationCheckDefinition>[
    nativeBuildCheck(
      workspaceRoot,
      executionRows,
      runCommand,
      identityDigest: identityDigest,
    ),
    nativeAbiCheck(executionRows, verifyAbi),
    developmentPathCheck(executionRows, verifyDevelopmentPath),
    externalConsumerCheck(executionRows, verifyExternalConsumer),
    artifactUniquenessCheck(executionRows, verifyArtifactUniqueness),
  ];
}

VerificationCheckDefinition nativeBuildCheck(
  String workspaceRoot,
  List<IntegrationExecutionRow> executionRows,
  VerificationCommandRunner runCommand, {
  VerificationNativePayloadIdentityDigester identityDigest =
      nexaHttpNativePayloadIdentitySha256,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
}) {
  return VerificationCheckDefinition(
    id: const VerificationCheckId('native-build'),
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    action: (context) async {
      await context.producePreparedArtifactIdentities(() async {
        final row = executionRows.singleWhere(
          (candidate) => candidate.executionId == context.executionId,
        );
        final absoluteWorkspaceRoot = Directory(workspaceRoot).absolute.path;
        final outputDirectory = nexaHttpNativeWorkspaceOutputDirectory(
          absoluteWorkspaceRoot,
        );
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
                p.join(absoluteWorkspaceRoot, 'scripts', buildScriptName),
                'debug',
                '--output-dir',
                outputDirectory,
                for (final target in targets) ...<String>['--target', target],
              ],
              workingDirectory: absoluteWorkspaceRoot,
            ),
          );
        }
        for (final target in row.targets) {
          await recordNexaHttpNativeWorkspaceArtifactFingerprint(
            absoluteWorkspaceRoot,
            target,
          );
        }
        return <VerifiedNativeArtifactIdentity>[
          for (final target in row.targets)
            await _workspaceArtifactIdentity(
              outputDirectory,
              target,
              identityDigest,
            ),
        ];
      });
    },
  );
}

Future<VerifiedNativeArtifactIdentity> _workspaceArtifactIdentity(
  String outputDirectory,
  NexaHttpNativeTarget target,
  VerificationNativePayloadIdentityDigester identityDigest,
) async {
  final file = File(
    p.join(outputDirectory, target.releaseAssetFileName),
  ).absolute;
  if (!file.existsSync()) {
    throw StateError(
      'Native build did not produce ${target.targetOS}/'
      '${target.targetArchitecture}/${target.targetSdk ?? 'none'} at '
      '${file.path}',
    );
  }
  return VerifiedNativeArtifactIdentity(
    target: target,
    file: file,
    sha256: await sha256OfFile(file),
    identitySha256: await identityDigest(file, platform: target.targetOS),
    sourceIdentity: 'workspace',
  );
}

VerificationCheckDefinition nativeAbiCheck(
  List<IntegrationExecutionRow> executionRows,
  VerificationNativeAbiCheckRunner verifyAbi,
) {
  return VerificationCheckDefinition(
    id: const VerificationCheckId('native-abi'),
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    dependencies: const <VerificationCheckId>[
      VerificationCheckId('native-build'),
    ],
    action: (context) async {
      await verifyAbi(await context.requirePreparedArtifactIdentities());
    },
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
  VerificationExternalConsumerCheckRunner verifyExternalConsumer,
) {
  return VerificationCheckDefinition(
    id: const VerificationCheckId('external-consumer'),
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    dependencies: const <VerificationCheckId>[
      VerificationCheckId('native-build'),
    ],
    action: (context) async {
      await verifyExternalConsumer(
        context.executionId,
        await context.requirePreparedArtifactIdentities(),
      );
    },
  );
}

VerificationCheckDefinition artifactUniquenessCheck(
  List<IntegrationExecutionRow> executionRows,
  VerificationArtifactUniquenessCheckRunner verifyArtifactUniqueness,
) {
  return VerificationCheckDefinition(
    id: const VerificationCheckId('artifact-uniqueness'),
    suites: const <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    dependencies: const <VerificationCheckId>[
      VerificationCheckId('external-consumer'),
    ],
    action: (context) async {
      await context
          .produceRuntimePayloadProofs<VerificationRuntimePayloadProof>(
            () => verifyArtifactUniqueness(context.executionId),
          );
    },
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
