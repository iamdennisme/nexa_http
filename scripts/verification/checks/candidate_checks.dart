import '../model.dart';
import '../target_matrix.dart';

typedef CandidateExecutionCheckRunner =
    Future<void> Function(VerificationExecutionId executionId);

List<VerificationCheckDefinition> buildCandidateChecks({
  required List<IntegrationExecutionRow> executionRows,
  required CandidateExecutionCheckRunner verifyCandidateSet,
  required CandidateExecutionCheckRunner verifyCandidateAbi,
  required CandidateExecutionCheckRunner verifyCandidateRuntime,
}) {
  final executionIds = executionRows
      .map((row) => row.executionId)
      .toList(growable: false);
  return <VerificationCheckDefinition>[
    _candidateCheck(
      id: const VerificationCheckId('candidate-set'),
      executionIds: executionIds,
      runCheck: verifyCandidateSet,
    ),
    _candidateCheck(
      id: const VerificationCheckId('candidate-abi'),
      executionIds: executionIds,
      dependencies: const <VerificationCheckId>[
        VerificationCheckId('candidate-set'),
      ],
      runCheck: verifyCandidateAbi,
    ),
    _candidateCheck(
      id: const VerificationCheckId('candidate-runtime'),
      executionIds: executionIds,
      dependencies: const <VerificationCheckId>[
        VerificationCheckId('candidate-set'),
      ],
      runCheck: verifyCandidateRuntime,
    ),
  ];
}

VerificationCheckDefinition _candidateCheck({
  required VerificationCheckId id,
  required List<VerificationExecutionId> executionIds,
  required CandidateExecutionCheckRunner runCheck,
  List<VerificationCheckId> dependencies = const <VerificationCheckId>[],
}) {
  return VerificationCheckDefinition(
    id: id,
    suites: const <VerificationSuiteId>[
      VerificationSuiteId.verifyReleaseCandidate,
    ],
    supportedExecutions: executionIds,
    dependencies: dependencies,
    action: (context) => runCheck(context.executionId),
  );
}
