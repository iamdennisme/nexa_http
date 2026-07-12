import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/checks/integration_checks.dart';
import '../../scripts/verification/executor.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/planner.dart';
import '../../scripts/verification/target_matrix.dart';

void main() {
  test('integration suite registers build and consumer checks once', () {
    final catalog = VerificationCatalog(
      buildIntegrationChecks(
        workspaceRoot: '/workspace',
        executionRows: buildIntegrationExecutionRows(),
        runCommand: (_) async {},
        verifyAbi: (_) async {},
        verifyDevelopmentPath: (_) async {},
        verifyExternalConsumer: (_) async {},
      ),
    );

    expect(
      catalog
          .checksForSuite(VerificationSuiteId.verifyIntegration)
          .map((check) => check.id.value),
      <String>[
        'development-path',
        'external-consumer',
        'native-abi',
        'native-build',
      ],
    );
  });

  test('Android execution invokes its platform build script once', () async {
    final commands = <VerificationCommand>[];
    final check = nativeBuildCheck(
      '/workspace',
      buildIntegrationExecutionRows(),
      (command) async => commands.add(command),
    );
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(catalog).planSuite(
      VerificationSuiteId.verifyIntegration,
      const VerificationExecutionId('android-linux'),
    );

    await const VerificationExecutor().execute(plan);

    expect(commands, hasLength(1));
    expect(commands.single.executable, 'bash');
    expect(commands.single.arguments, <String>[
      '/workspace/scripts/build_native_android.sh',
      'debug',
    ]);
  });

  test('Apple ABI verification reuses one grouped platform build', () async {
    final rows = buildIntegrationExecutionRows();
    final commands = <VerificationCommand>[];
    final abiExecutions = <VerificationExecutionId>[];
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[
      nativeBuildCheck(
        '/workspace',
        rows,
        (command) async => commands.add(command),
      ),
      nativeAbiCheck(
        rows,
        (executionId) async => abiExecutions.add(executionId),
      ),
    ]);
    final plan = VerificationPlanner(catalog).planSuite(
      VerificationSuiteId.verifyIntegration,
      const VerificationExecutionId('apple-macos'),
    );

    await const VerificationExecutor().execute(plan);

    expect(commands.map((command) => command.arguments.first), <String>[
      '/workspace/scripts/build_native_ios.sh',
      '/workspace/scripts/build_native_macos.sh',
    ]);
    expect(abiExecutions, <VerificationExecutionId>[
      const VerificationExecutionId('apple-macos'),
    ]);
  });

  test('development path runs after the Windows build producer', () async {
    final rows = buildIntegrationExecutionRows();
    final commands = <VerificationCommand>[];
    final developmentExecutions = <VerificationExecutionId>[];
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[
      nativeBuildCheck(
        '/workspace',
        rows,
        (command) async => commands.add(command),
      ),
      developmentPathCheck(
        rows,
        (executionId) async => developmentExecutions.add(executionId),
      ),
    ]);
    final plan = VerificationPlanner(catalog).planSuite(
      VerificationSuiteId.verifyIntegration,
      const VerificationExecutionId('windows-x64'),
    );

    await const VerificationExecutor().execute(plan);

    expect(commands, hasLength(1));
    expect(
      commands.single.arguments.first,
      '/workspace/scripts/build_native_windows.sh',
    );
    expect(developmentExecutions, <VerificationExecutionId>[
      const VerificationExecutionId('windows-x64'),
    ]);
  });
}
