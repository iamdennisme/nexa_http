import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/checks/candidate_checks.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/target_matrix.dart';

void main() {
  test(
    'release-candidate suite registers validation without a build check',
    () {
      final catalog = VerificationCatalog(
        buildCandidateChecks(
          executionRows: buildReleaseCandidateExecutionRows(),
          verifyCandidateSet: (_) async {},
          verifyCandidateAbi: (_) async {},
          verifyCandidateRuntime: (_) async {},
        ),
      );

      expect(
        catalog
            .checksForSuite(VerificationSuiteId.verifyReleaseCandidate)
            .map((check) => check.id.value),
        <String>['candidate-abi', 'candidate-runtime', 'candidate-set'],
      );
      expect(
        catalog.checks.map((check) => check.id.value),
        isNot(contains('native-build')),
      );
    },
  );
}
