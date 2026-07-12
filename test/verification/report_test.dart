import 'package:test/test.dart';

import '../../scripts/verification/model.dart';
import '../../scripts/verification/report.dart';

void main() {
  test('aggregate accepts exactly one complete report per execution row', () {
    final reports = <VerificationCoverageReport>[
      VerificationCoverageReport(
        suiteId: VerificationSuiteId.verifyIntegration,
        executionId: const VerificationExecutionId('android-linux'),
        plannedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
          VerificationCheckId('native-abi'),
        ],
        completedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
          VerificationCheckId('native-abi'),
        ],
        status: VerificationCoverageStatus.passed,
      ),
      VerificationCoverageReport(
        suiteId: VerificationSuiteId.verifyIntegration,
        executionId: const VerificationExecutionId('windows-x64'),
        plannedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
          VerificationCheckId('native-abi'),
        ],
        completedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
          VerificationCheckId('native-abi'),
        ],
        status: VerificationCoverageStatus.passed,
      ),
    ];

    expect(
      () => verifyAggregateCoverage(
        suiteId: VerificationSuiteId.verifyIntegration,
        expectedExecutionIds: const <VerificationExecutionId>[
          VerificationExecutionId('android-linux'),
          VerificationExecutionId('windows-x64'),
        ],
        expectedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
          VerificationCheckId('native-abi'),
        ],
        reports: reports,
      ),
      returnsNormally,
    );
  });

  test('aggregate rejects a duplicate execution report', () {
    final report = VerificationCoverageReport(
      suiteId: VerificationSuiteId.verifyStatic,
      executionId: const VerificationExecutionId('static-linux'),
      plannedCheckIds: const <VerificationCheckId>[
        VerificationCheckId('workspace-dart-analyze'),
      ],
      completedCheckIds: const <VerificationCheckId>[
        VerificationCheckId('workspace-dart-analyze'),
      ],
      status: VerificationCoverageStatus.passed,
    );

    expect(
      () => verifyAggregateCoverage(
        suiteId: VerificationSuiteId.verifyStatic,
        expectedExecutionIds: const <VerificationExecutionId>[
          VerificationExecutionId('static-linux'),
        ],
        expectedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('workspace-dart-analyze'),
        ],
        reports: <VerificationCoverageReport>[report, report],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('coverage report JSON preserves the machine-readable contract', () {
    final report = VerificationCoverageReport(
      suiteId: VerificationSuiteId.verifyStatic,
      executionId: const VerificationExecutionId('static-linux'),
      plannedCheckIds: const <VerificationCheckId>[
        VerificationCheckId('workspace-dart-analyze'),
      ],
      completedCheckIds: const <VerificationCheckId>[
        VerificationCheckId('workspace-dart-analyze'),
      ],
      status: VerificationCoverageStatus.passed,
    );

    expect(VerificationCoverageReport.fromJson(report.toJson()).toJson(), {
      'schema_version': 1,
      'suite_id': 'verify-static',
      'execution_id': 'static-linux',
      'planned_check_ids': <String>['workspace-dart-analyze'],
      'completed_check_ids': <String>['workspace-dart-analyze'],
      'status': 'passed',
    });
  });
}
