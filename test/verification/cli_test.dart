import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';

import '../../scripts/verification/cli.dart';
import '../../scripts/verification/command.dart';
import '../../scripts/verification/candidate_set.dart';
import '../../scripts/verification/model.dart';

void main() {
  test('parses bootstrap as a workspace utility command', () {
    final command = parseVerificationCliCommand(const <String>['bootstrap']);

    expect(command.name, 'bootstrap');
    expect(command.arguments, isEmpty);
  });

  test('parses the canonical verification command surface', () {
    for (final commandName in const <String>[
      'verify-static',
      'verify-integration',
      'verify-release-candidate',
      'check',
      'matrix',
    ]) {
      final command = parseVerificationCliCommand(<String>[
        commandName,
        '--example',
      ]);

      expect(command.name, commandName);
      expect(command.arguments, <String>['--example']);
    }
  });

  test('rejects the removed generic verify command', () {
    expect(
      () => parseVerificationCliCommand(const <String>['verify']),
      throwsA(
        isA<VerificationCliUsageError>().having(
          (error) => error.message,
          'message',
          contains('Unknown workspace command: verify'),
        ),
      ),
    );
  });

  test('check runs one Catalog diagnostic by ID', () async {
    final commands = <VerificationCommand>[];

    final exitCode = await runVerificationCli(
      const <String>['check', 'rust-format', '--execution', 'static-linux'],
      workspaceRoot: '/workspace',
      runCommand: (command) async => commands.add(command),
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, hasLength(1));
    expect(commands.single.executable, 'cargo');
    expect(commands.single.arguments, <String>[
      'fmt',
      '--all',
      '--',
      '--check',
    ]);
  });

  test('matrix command writes only machine-readable JSON to stdout', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runVerificationCli(
      const <String>['matrix', '--suite', 'verify-integration'],
      writeStdout: stdoutLines.add,
      writeStderr: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stdoutLines, hasLength(1));
    expect(jsonDecode(stdoutLines.single), isA<Map<String, Object?>>());
    expect(stderrLines, isEmpty);
  });

  test('verify-static executes the Catalog plan for one execution', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_verify_static_cli_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });
    await Directory('${workspace.path}/packages').create();
    final commands = <VerificationCommand>[];

    final exitCode = await runVerificationCli(
      const <String>['verify-static', '--execution', 'static-linux'],
      workspaceRoot: workspace.path,
      runCommand: (command) async => commands.add(command),
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, hasLength(6));
  });

  test('suite execution writes a machine-readable coverage report', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_verify_report_cli_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });
    await Directory('${workspace.path}/packages').create();
    final reportFile = File('${workspace.path}/reports/static-linux.json');

    final exitCode = await runVerificationCli(
      <String>[
        'verify-static',
        '--execution',
        'static-linux',
        '--report-out',
        reportFile.path,
      ],
      workspaceRoot: workspace.path,
      runCommand: (_) async {},
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(jsonDecode(await reportFile.readAsString()), {
      'schema_version': 1,
      'suite_id': 'verify-static',
      'execution_id': 'static-linux',
      'planned_check_ids': <String>[
        'generated-bindings-freshness',
        'root-contract-test',
        'rust-clippy',
        'rust-format',
        'rust-workspace-test',
        'workspace-dart-analyze',
        'workspace-dart-test',
      ],
      'completed_check_ids': <String>[
        'generated-bindings-freshness',
        'root-contract-test',
        'rust-clippy',
        'rust-format',
        'rust-workspace-test',
        'workspace-dart-analyze',
        'workspace-dart-test',
      ],
      'status': 'passed',
    });
  });

  test('aggregate mode validates reports without executing checks', () async {
    final reportDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_aggregate_reports_',
    );
    addTearDown(() async {
      if (reportDirectory.existsSync()) {
        await reportDirectory.delete(recursive: true);
      }
    });
    await File('${reportDirectory.path}/static-linux.json').writeAsString(
      jsonEncode(<String, Object?>{
        'schema_version': 1,
        'suite_id': 'verify-static',
        'execution_id': 'static-linux',
        'planned_check_ids': <String>[
          'generated-bindings-freshness',
          'root-contract-test',
          'rust-clippy',
          'rust-format',
          'rust-workspace-test',
          'workspace-dart-analyze',
          'workspace-dart-test',
        ],
        'completed_check_ids': <String>[
          'generated-bindings-freshness',
          'root-contract-test',
          'rust-clippy',
          'rust-format',
          'rust-workspace-test',
          'workspace-dart-analyze',
          'workspace-dart-test',
        ],
        'status': 'passed',
      }),
    );
    final commands = <VerificationCommand>[];

    final exitCode = await runVerificationCli(
      <String>['verify-static', '--aggregate-reports', reportDirectory.path],
      runCommand: (command) async => commands.add(command),
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, isEmpty);
  });

  test(
    'verify-integration executes one grouped build and its consumers',
    () async {
      final commands = <VerificationCommand>[];
      final abiExecutions = <VerificationExecutionId>[];
      final developmentExecutions = <VerificationExecutionId>[];
      final externalExecutions = <VerificationExecutionId>[];

      final exitCode = await runVerificationCli(
        const <String>[
          'verify-integration',
          '--execution',
          'android-linux',
          '--fixture-url',
          'http://127.0.0.1:8080/healthz',
          '--device',
          'android=emulator-id',
        ],
        workspaceRoot: '/workspace',
        runCommand: (command) async => commands.add(command),
        verifyAbi: (executionId) async => abiExecutions.add(executionId),
        verifyDevelopmentPath: (executionId) async =>
            developmentExecutions.add(executionId),
        verifyExternalConsumer: (executionId) async =>
            externalExecutions.add(executionId),
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      expect(commands, hasLength(1));
      expect(abiExecutions, hasLength(1));
      expect(developmentExecutions, hasLength(1));
      expect(externalExecutions, hasLength(1));
    },
  );

  test('verify-integration writes row coverage', () async {
    final temp = await Directory.systemTemp.createTemp(
      'nexa_http_integration_report_',
    );
    addTearDown(() async => temp.delete(recursive: true));
    final reportFile = File('${temp.path}/android-linux.json');

    final exitCode = await runVerificationCli(
      <String>[
        'verify-integration',
        '--execution',
        'android-linux',
        '--fixture-url',
        'http://127.0.0.1:8080/healthz',
        '--device',
        'android=emulator-id',
        '--report-out',
        reportFile.path,
      ],
      workspaceRoot: '/workspace',
      runCommand: (_) async {},
      verifyAbi: (_) async {},
      verifyDevelopmentPath: (_) async {},
      verifyExternalConsumer: (_) async {},
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(
      (jsonDecode(await reportFile.readAsString()) as Map)['suite_id'],
      'verify-integration',
    );
  });

  test('integration diagnostic reuses its Catalog build dependency', () async {
    final commands = <VerificationCommand>[];
    final abiExecutions = <VerificationExecutionId>[];

    final exitCode = await runVerificationCli(
      const <String>[
        'check',
        'native-abi',
        '--execution',
        'android-linux',
        '--fixture-url',
        'http://127.0.0.1:8080/healthz',
        '--device',
        'android=emulator-id',
      ],
      workspaceRoot: '/workspace',
      runCommand: (command) async => commands.add(command),
      verifyAbi: (executionId) async => abiExecutions.add(executionId),
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, hasLength(1));
    expect(abiExecutions, const <VerificationExecutionId>[
      VerificationExecutionId('android-linux'),
    ]);
  });

  test(
    'verify-integration aggregate requires all three execution rows',
    () async {
      final reportDirectory = await Directory.systemTemp.createTemp(
        'nexa_http_integration_aggregate_',
      );
      addTearDown(() async => reportDirectory.delete(recursive: true));
      for (final executionId in <String>[
        'android-linux',
        'apple-macos',
        'windows-x64',
      ]) {
        await File('${reportDirectory.path}/$executionId.json').writeAsString(
          jsonEncode(<String, Object?>{
            'schema_version': 1,
            'suite_id': 'verify-integration',
            'execution_id': executionId,
            'planned_check_ids': <String>[
              'native-build',
              'development-path',
              'external-consumer',
              'native-abi',
            ],
            'completed_check_ids': <String>[
              'native-build',
              'development-path',
              'external-consumer',
              'native-abi',
            ],
            'status': 'passed',
          }),
        );
      }

      final exitCode = await runVerificationCli(
        <String>[
          'verify-integration',
          '--aggregate-reports',
          reportDirectory.path,
        ],
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
    },
  );

  test('parses explicit integration fixture and device inputs', () {
    final input = parseIntegrationCliInput(const <String>[
      '--execution',
      'apple-macos',
      '--fixture-url',
      'http://127.0.0.1:8080/healthz',
      '--device',
      'ios=simulator-id',
      '--device',
      'macos=macos-id',
    ]);

    expect(input.executionId.value, 'apple-macos');
    expect(input.fixtureUrl, Uri.parse('http://127.0.0.1:8080/healthz'));
    expect(input.deviceIds, <String, String>{
      'ios': 'simulator-id',
      'macos': 'macos-id',
    });
  });

  test('parses explicit release-candidate identity and runtime inputs', () {
    final digest = List<String>.filled(64, 'a').join();
    final input = parseCandidateCliInput(<String>[
      '--execution',
      'candidate-macos',
      '--candidate-dir',
      '/candidate',
      '--candidate-id',
      'candidate-42',
      '--candidate-digest',
      digest,
      '--sdk-ref',
      '20c3786',
      '--fixture-url',
      'http://127.0.0.1:8080/healthz',
      '--device',
      'macos=macos-id',
    ]);

    expect(input.executionId.value, 'candidate-macos');
    expect(input.candidateDirectory.path, '/candidate');
    expect(input.candidateId, 'candidate-42');
    expect(input.expectedDigest, digest);
    expect(input.sdkRef, '20c3786');
    expect(input.deviceId, 'macos-id');
  });

  test(
    'verify-release-candidate validates once and runs the staged candidate',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'nexa_http_candidate_report_',
      );
      addTearDown(() async => temp.delete(recursive: true));
      final reportFile = File('${temp.path}/candidate-macos.json');
      final digest = List<String>.filled(64, 'a').join();
      var setRuns = 0;
      final consumers = <String>[];
      final commands = <VerificationCommand>[];
      final verified = VerifiedCandidateSet(
        candidateDirectory: Directory('/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: digest,
        artifactDigests: const <String, String>{},
        artifactFiles: <String, File>{},
      );

      final exitCode = await runVerificationCli(
        <String>[
          'verify-release-candidate',
          '--execution',
          'candidate-macos',
          '--candidate-dir',
          '/candidate',
          '--candidate-id',
          'candidate-42',
          '--candidate-digest',
          digest,
          '--sdk-ref',
          '20c3786',
          '--fixture-url',
          'http://127.0.0.1:8080/healthz',
          '--device',
          'macos=macos-id',
          '--report-out',
          reportFile.path,
        ],
        runCommand: (command) async => commands.add(command),
        candidateSetLoader: () async {
          setRuns += 1;
          return verified;
        },
        verifyCandidateAbi: (candidate, executionId) async =>
            consumers.add('abi'),
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      expect(setRuns, 1);
      expect(consumers, <String>['abi']);
      expect(commands, hasLength(4));
      for (final command in commands) {
        expect(command.environment, <String, String>{
          'NEXA_HTTP_NATIVE_CANDIDATE_DIR': '/candidate',
          'NEXA_HTTP_NATIVE_CANDIDATE_REF': '20c3786',
        });
      }
      expect(
        (jsonDecode(await reportFile.readAsString()) as Map)['suite_id'],
        'verify-release-candidate',
      );
    },
  );

  test(
    'release-candidate aggregate requires four blocking platforms',
    () async {
      final reportDirectory = await Directory.systemTemp.createTemp(
        'nexa_http_candidate_aggregate_',
      );
      addTearDown(() async => reportDirectory.delete(recursive: true));
      for (final executionId in <String>[
        'candidate-android',
        'candidate-ios',
        'candidate-macos',
        'candidate-windows',
      ]) {
        await File('${reportDirectory.path}/$executionId.json').writeAsString(
          jsonEncode(<String, Object?>{
            'schema_version': 1,
            'suite_id': 'verify-release-candidate',
            'execution_id': executionId,
            'planned_check_ids': <String>[
              'candidate-set',
              'candidate-abi',
              'candidate-runtime',
            ],
            'completed_check_ids': <String>[
              'candidate-set',
              'candidate-abi',
              'candidate-runtime',
            ],
            'status': 'passed',
          }),
        );
      }

      final exitCode = await runVerificationCli(
        <String>[
          'verify-release-candidate',
          '--aggregate-reports',
          reportDirectory.path,
        ],
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
    },
  );

  test(
    'candidate diagnostic consumes the verified set without runtime',
    () async {
      final digest = List<String>.filled(64, 'a').join();
      var setRuns = 0;
      final consumers = <String>[];
      final verified = VerifiedCandidateSet(
        candidateDirectory: Directory('/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: digest,
        artifactDigests: const <String, String>{},
        artifactFiles: <String, File>{},
      );

      final exitCode = await runVerificationCli(
        <String>[
          'check',
          'candidate-abi',
          '--execution',
          'candidate-macos',
          '--candidate-dir',
          '/candidate',
          '--candidate-id',
          'candidate-42',
          '--candidate-digest',
          digest,
          '--sdk-ref',
          '20c3786',
          '--fixture-url',
          'http://127.0.0.1:8080/healthz',
          '--device',
          'macos=macos-id',
        ],
        candidateSetLoader: () async {
          setRuns += 1;
          return verified;
        },
        verifyCandidateAbi: (candidate, executionId) async =>
            consumers.add('abi'),
        verifyCandidateRuntime: (candidate, executionId) async =>
            consumers.add('runtime'),
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      expect(setRuns, 1);
      expect(consumers, <String>['abi']);
    },
  );

  test('released-consumer remains a Catalog diagnostic only', () async {
    final commands = <VerificationCommand>[];

    final exitCode = await runVerificationCli(
      const <String>[
        'check',
        'released-consumer',
        '--execution',
        'windows-x64',
        '--repo-url',
        'https://github.com/example/nexa_http.git',
        '--ref',
        'v2.0.0',
        '--fixture-url',
        'http://127.0.0.1:8080/healthz',
        '--device',
        'windows=windows',
      ],
      runCommand: (command) async => commands.add(command),
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, hasLength(4));
  });
}
