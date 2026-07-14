import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/planner.dart';

void main() {
  test('plans a shared dependency once for one execution scope', () {
    const executionId = VerificationExecutionId('android-linux');
    final catalog = VerificationCatalog(const <VerificationCheckDefinition>[
      VerificationCheckDefinition(
        id: VerificationCheckId('native-build'),
        supportedExecutions: <VerificationExecutionId>[executionId],
      ),
      VerificationCheckDefinition(
        id: VerificationCheckId('native-abi'),
        suites: <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
        supportedExecutions: <VerificationExecutionId>[executionId],
        dependencies: <VerificationCheckId>[
          VerificationCheckId('native-build'),
        ],
      ),
      VerificationCheckDefinition(
        id: VerificationCheckId('external-consumer'),
        suites: <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
        supportedExecutions: <VerificationExecutionId>[executionId],
        dependencies: <VerificationCheckId>[
          VerificationCheckId('native-build'),
        ],
      ),
    ]);

    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyIntegration, executionId);

    expect(plan.nodes.map((node) => node.check.id.value), <String>[
      'native-build',
      'external-consumer',
      'native-abi',
    ]);
    expect(plan.nodes.map((node) => node.key.value), <String>[
      'native-build@android-linux',
      'external-consumer@android-linux',
      'native-abi@android-linux',
    ]);
  });

  test('rejects suite checks outside the requested execution', () {
    final catalog = VerificationCatalog(const <VerificationCheckDefinition>[
      VerificationCheckDefinition(
        id: VerificationCheckId('android-native-build'),
        suites: <VerificationSuiteId>[VerificationSuiteId.verifyIntegration],
        supportedExecutions: <VerificationExecutionId>[
          VerificationExecutionId('android-linux'),
        ],
      ),
    ]);

    expect(
      () => VerificationPlanner(catalog).planSuite(
        VerificationSuiteId.verifyIntegration,
        const VerificationExecutionId('windows-x64'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Check android-native-build is not covered by execution windows-x64',
          ),
        ),
      ),
    );
  });

  test('atomic diagnostic plans the selected check and its dependency', () {
    const executionId = VerificationExecutionId('android-linux');
    final catalog = VerificationCatalog(const <VerificationCheckDefinition>[
      VerificationCheckDefinition(
        id: VerificationCheckId('native-build'),
        supportedExecutions: <VerificationExecutionId>[executionId],
      ),
      VerificationCheckDefinition(
        id: VerificationCheckId('native-abi'),
        supportedExecutions: <VerificationExecutionId>[executionId],
        dependencies: <VerificationCheckId>[
          VerificationCheckId('native-build'),
        ],
      ),
    ]);

    final plan = VerificationPlanner(
      catalog,
    ).planCheck(const VerificationCheckId('native-abi'), executionId);

    expect(plan.nodes.map((node) => node.check.id.value), <String>[
      'native-build',
      'native-abi',
    ]);
  });
}
