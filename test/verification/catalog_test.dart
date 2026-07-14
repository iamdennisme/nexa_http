import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/model.dart';

void main() {
  test('rejects duplicate check IDs', () {
    const checkId = VerificationCheckId('workspace-dart-analyze');

    expect(
      () => VerificationCatalog(<VerificationCheckDefinition>[
        const VerificationCheckDefinition(id: checkId),
        const VerificationCheckDefinition(id: checkId),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Duplicate verification check ID: workspace-dart-analyze'),
        ),
      ),
    );
  });

  test('rejects unknown suite IDs', () {
    expect(
      () => VerificationCatalog(const <VerificationCheckDefinition>[
        VerificationCheckDefinition(
          id: VerificationCheckId('workspace-dart-analyze'),
          suites: <VerificationSuiteId>[VerificationSuiteId('verify-unknown')],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Unknown verification suite ID: verify-unknown'),
        ),
      ),
    );
  });

  test('rejects duplicate suite membership', () {
    expect(
      () => VerificationCatalog(const <VerificationCheckDefinition>[
        VerificationCheckDefinition(
          id: VerificationCheckId('workspace-dart-analyze'),
          suites: <VerificationSuiteId>[
            VerificationSuiteId.verifyStatic,
            VerificationSuiteId.verifyStatic,
          ],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Duplicate suite membership: workspace-dart-analyze in verify-static',
          ),
        ),
      ),
    );
  });

  test('rejects suite checks without execution coverage', () {
    expect(
      () => VerificationCatalog(const <VerificationCheckDefinition>[
        VerificationCheckDefinition(
          id: VerificationCheckId('workspace-dart-analyze'),
          suites: <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'No execution coverage for check workspace-dart-analyze in verify-static',
          ),
        ),
      ),
    );
  });

  test('returns suite checks in stable ID order', () {
    const executionId = VerificationExecutionId('static-linux');
    final catalog = VerificationCatalog(const <VerificationCheckDefinition>[
      VerificationCheckDefinition(
        id: VerificationCheckId('workspace-dart-test'),
        suites: <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
        supportedExecutions: <VerificationExecutionId>[executionId],
      ),
      VerificationCheckDefinition(
        id: VerificationCheckId('workspace-dart-analyze'),
        suites: <VerificationSuiteId>[VerificationSuiteId.verifyStatic],
        supportedExecutions: <VerificationExecutionId>[executionId],
      ),
    ]);

    expect(
      catalog
          .checksForSuite(VerificationSuiteId.verifyStatic)
          .map((check) => check.id.value),
      <String>['workspace-dart-analyze', 'workspace-dart-test'],
    );
  });

  test('rejects unknown check dependencies', () {
    expect(
      () => VerificationCatalog(const <VerificationCheckDefinition>[
        VerificationCheckDefinition(
          id: VerificationCheckId('workspace-dart-test'),
          dependencies: <VerificationCheckId>[
            VerificationCheckId('workspace-dart-analyze'),
          ],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Unknown verification check dependency: workspace-dart-test -> workspace-dart-analyze',
          ),
        ),
      ),
    );
  });

  test('rejects check dependency cycles', () {
    expect(
      () => VerificationCatalog(const <VerificationCheckDefinition>[
        VerificationCheckDefinition(
          id: VerificationCheckId('workspace-dart-analyze'),
          dependencies: <VerificationCheckId>[
            VerificationCheckId('workspace-dart-test'),
          ],
        ),
        VerificationCheckDefinition(
          id: VerificationCheckId('workspace-dart-test'),
          dependencies: <VerificationCheckId>[
            VerificationCheckId('workspace-dart-analyze'),
          ],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Verification check dependency cycle'),
        ),
      ),
    );
  });
}
