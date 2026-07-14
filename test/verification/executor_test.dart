import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/executor.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/planner.dart';

void main() {
  test('memoizes a shared resource once per suite execution', () async {
    const executionId = VerificationExecutionId('static-linux');
    const resourceKey = VerificationResourceKey('workspace-inventory');
    var producerRuns = 0;

    Future<void> consumeInventory(VerificationRunContext context) async {
      await context.memoize(resourceKey, () async {
        producerRuns += 1;
        return Object();
      });
    }

    final catalog = VerificationCatalog(<VerificationCheckDefinition>[
      VerificationCheckDefinition(
        id: const VerificationCheckId('workspace-dart-analyze'),
        suites: const <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
        supportedExecutions: const <VerificationExecutionId>[executionId],
        action: consumeInventory,
      ),
      VerificationCheckDefinition(
        id: const VerificationCheckId('workspace-dart-test'),
        suites: const <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
        supportedExecutions: const <VerificationExecutionId>[executionId],
        action: consumeInventory,
      ),
    ]);
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, executionId);

    final result = await const VerificationExecutor().execute(plan);

    expect(producerRuns, 1);
    expect(result.completedCheckIds, const <VerificationCheckId>[
      VerificationCheckId('workspace-dart-analyze'),
      VerificationCheckId('workspace-dart-test'),
    ]);
  });
}
