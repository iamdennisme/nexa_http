import 'dart:io';
import 'dart:convert';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/verification/cli.dart';
import '../../scripts/verification/command.dart';
import '../../scripts/verification/candidate_set.dart';
import '../../scripts/verification/external_consumer_adapter.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/report.dart';
import '../../scripts/verification/target_matrix.dart';

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
    expect(commands, hasLength(10));
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
      'schema_version': 2,
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
      'prepared_artifacts': <Object?>[],
      'runtime_payloads': <Object?>[],
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
        'schema_version': 2,
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
        'prepared_artifacts': <Object?>[],
        'runtime_payloads': <Object?>[],
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
      final workspace = await Directory.systemTemp.createTemp(
        'nexa_http_cli_integration_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final commands = <VerificationCommand>[];
      final abiIdentities = <List<VerifiedNativeArtifactIdentity>>[];
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
        workspaceRoot: workspace.path,
        runCommand: (command) async {
          commands.add(command);
          await _writeNativeBuildOutputs(command);
        },
        verifyAbi: (identities) async => abiIdentities.add(identities),
        verifyDevelopmentPath: (executionId) async =>
            developmentExecutions.add(executionId),
        verifyExternalConsumer: (executionId, _) async =>
            externalExecutions.add(executionId),
        verifyArtifactUniqueness: (_) async =>
            const <VerificationRuntimePayloadProof>[],
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      expect(commands, hasLength(1));
      expect(abiIdentities.single, hasLength(3));
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
    final workspace = Directory('${temp.path}/workspace');
    await workspace.create();

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
      workspaceRoot: workspace.path,
      runCommand: _writeNativeBuildOutputs,
      verifyAbi: (_) async {},
      verifyDevelopmentPath: (_) async {},
      verifyExternalConsumer: (_, _) async {},
      verifyArtifactUniqueness: (_) async =>
          const <VerificationRuntimePayloadProof>[],
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
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_cli_diagnostic_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final commands = <VerificationCommand>[];
    final abiIdentities = <List<VerifiedNativeArtifactIdentity>>[];

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
      workspaceRoot: workspace.path,
      runCommand: (command) async {
        commands.add(command);
        await _writeNativeBuildOutputs(command);
      },
      verifyAbi: (identities) async => abiIdentities.add(identities),
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, hasLength(1));
    expect(abiIdentities.single, hasLength(3));
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
          jsonEncode(
            _completeNativeReportJson(
              suiteId: VerificationSuiteId.verifyIntegration,
              executionId: VerificationExecutionId(executionId),
              checkIds: const <VerificationCheckId>[
                VerificationCheckId('native-build'),
                VerificationCheckId('development-path'),
                VerificationCheckId('external-consumer'),
                VerificationCheckId('artifact-uniqueness'),
                VerificationCheckId('native-abi'),
              ],
            ),
          ),
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
      'gha:42:314',
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
    expect(input.candidateId, 'gha:42:314');
    expect(input.expectedDigest, digest);
    expect(input.sdkRef, '20c3786');
    expect(input.deviceId, 'macos-id');

    expect(
      () => parseCandidateCliInput(<String>[
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
      ]),
      throwsA(isA<VerificationCliUsageError>()),
    );
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
      var identityDigestRuns = 0;
      final consumers = <String>[];
      final commands = <VerificationCommand>[];
      final verified = _verifiedCandidateForExecution(
        const VerificationExecutionId('candidate-macos'),
        candidateDirectory: Directory('/candidate'),
        candidateId: 'gha:42:314',
        sdkRef: '20c3786',
        digest: digest,
      );
      final runtimeProofTracker = ExternalRuntimeProofMarkerTracker();
      String? consumerPubspec;

      final exitCode = await runVerificationCli(
        <String>[
          'verify-release-candidate',
          '--execution',
          'candidate-macos',
          '--candidate-dir',
          '/candidate',
          '--candidate-id',
          'gha:42:314',
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
        runCommand: (command) async {
          commands.add(command);
          final pubspec = File(
            p.join(command.workingDirectory, 'pubspec.yaml'),
          );
          if (pubspec.existsSync()) {
            consumerPubspec = await pubspec.readAsString();
          }
          if (command.arguments case <String>[
            'create',
            '--platforms=macos',
            _,
            _,
          ]) {
            await _writeMacosEntitlementFixtures(command.workingDirectory);
          }
          if (command.arguments case <String>['run', ...]) {
            runtimeProofTracker.observeLine(_runtimeProofMarkerLine);
          }
        },
        runtimeProofTracker: runtimeProofTracker,
        candidateIdentityDigester: (file, {required platform}) async {
          identityDigestRuns += 1;
          return verified.artifactDigests[p.basename(file.path)]!;
        },
        candidateSetLoader: () async {
          setRuns += 1;
          return verified;
        },
        verifyCandidateAbi: (candidate, executionId) async =>
            consumers.add('abi'),
        verifyCandidateBuiltPayload: (_, _, prepared) async =>
            <VerificationRuntimePayloadProof>[
              _runtimeProofFromPrepared(prepared.first),
            ],
        writeStdout: (_) {},
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      expect(setRuns, 1);
      expect(identityDigestRuns, 2);
      expect(consumers, <String>['abi']);
      expect(commands, hasLength(4));
      for (final command in commands) {
        expect(command.environment, isEmpty);
      }
      expect(
        consumerPubspec,
        contains('candidate_directory: "file:///candidate"'),
      );
      expect(consumerPubspec, contains('candidate_ref: "20c3786"'));
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
          jsonEncode(
            _completeNativeReportJson(
              suiteId: VerificationSuiteId.verifyReleaseCandidate,
              executionId: VerificationExecutionId(executionId),
              checkIds: const <VerificationCheckId>[
                VerificationCheckId('candidate-set'),
                VerificationCheckId('candidate-abi'),
                VerificationCheckId('candidate-runtime'),
              ],
            ),
          ),
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
        candidateId: 'gha:42:314',
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
          'gha:42:314',
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
        verifyCandidateRuntime:
            (candidate, executionId, preparedArtifactProofs) async {
              consumers.add('runtime');
              return const <VerificationRuntimePayloadProof>[];
            },
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
    final runtimeProofTracker = ExternalRuntimeProofMarkerTracker();

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
      runCommand: (command) async {
        commands.add(command);
        if (command.arguments case <String>['run', ...]) {
          runtimeProofTracker.observeLine(_runtimeProofMarkerLine);
        }
      },
      runtimeProofTracker: runtimeProofTracker,
      writeStdout: (_) {},
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(commands, hasLength(4));
  });
}

Future<void> _writeNativeBuildOutputs(VerificationCommand command) async {
  if (!command.arguments.contains('--output-dir')) {
    return;
  }
  final outputDirectory = Directory(
    command.arguments[command.arguments.indexOf('--output-dir') + 1],
  );
  await outputDirectory.create(recursive: true);
  final requestedTriples = <String>[
    for (var index = 0; index < command.arguments.length; index++)
      if (command.arguments[index] == '--target') command.arguments[index + 1],
  ];
  for (final target in nexaHttpSupportedNativeTargets.where(
    (target) => requestedTriples.contains(target.rustTargetTriple),
  )) {
    await File(
      p.join(outputDirectory.path, target.releaseAssetFileName),
    ).writeAsString(target.rustTargetTriple);
  }
}

Map<String, Object?> _completeNativeReportJson({
  required VerificationSuiteId suiteId,
  required VerificationExecutionId executionId,
  required List<VerificationCheckId> checkIds,
}) {
  final rows = suiteId == VerificationSuiteId.verifyIntegration
      ? buildIntegrationExecutionRows()
      : buildReleaseCandidateExecutionRows();
  final row = rows.singleWhere(
    (candidate) => candidate.executionId == executionId,
  );
  final prepared = <VerificationPreparedArtifactProof>[
    for (var index = 0; index < row.targets.length; index++)
      VerificationPreparedArtifactProof(
        target: _proofTuple(row.targets[index]),
        nativeAssetId: row.targets[index].nativeAssetId,
        absolutePreparedFile:
            '/prepared/${row.targets[index].releaseAssetFileName}',
        sha256: List<String>.filled(64, (index + 1).toRadixString(16)).join(),
        identitySha256: List<String>.filled(
          64,
          (index + 1).toRadixString(16),
        ).join(),
        sourceIdentity: suiteId == VerificationSuiteId.verifyIntegration
            ? 'workspace'
            : 'candidate:gha:42:314:'
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
  ];
  final firstPreparedByPlatform = <String, VerificationPreparedArtifactProof>{};
  for (final proof in prepared) {
    firstPreparedByPlatform.putIfAbsent(proof.target.targetOS, () => proof);
  }
  final runtime = <VerificationRuntimePayloadProof>[
    for (final proof in firstPreparedByPlatform.values)
      _runtimeProofFromPrepared(proof),
  ];
  return VerificationCoverageReport(
    suiteId: suiteId,
    executionId: executionId,
    plannedCheckIds: checkIds,
    completedCheckIds: checkIds,
    status: VerificationCoverageStatus.passed,
    preparedArtifactProofs: prepared,
    runtimePayloadProofs: runtime,
  ).toJson();
}

VerificationNativeTargetTuple _proofTuple(NexaHttpNativeTarget target) {
  return VerificationNativeTargetTuple(
    targetOS: target.targetOS,
    targetArchitecture: target.targetArchitecture,
    targetSdk: target.targetSdk,
    rustTarget: target.rustTargetTriple,
  );
}

VerificationRuntimePayloadProof _runtimeProofFromPrepared(
  VerificationPreparedArtifactProof prepared,
) {
  return VerificationRuntimePayloadProof(
    target: prepared.target,
    nativeAssetId: prepared.nativeAssetId,
    absolutePackagedFile:
        '/packaged/${p.basename(prepared.absolutePreparedFile)}',
    sha256: prepared.sha256,
    identitySha256: prepared.identitySha256,
    payloadCount: 1,
    requestCompleted: true,
    callbackReceived: true,
    bodyConsumed: true,
    bodyReleased: true,
    clientClosed: true,
  );
}

VerifiedCandidateSet _verifiedCandidateForExecution(
  VerificationExecutionId executionId, {
  required Directory candidateDirectory,
  required String candidateId,
  required String sdkRef,
  required String digest,
}) {
  final row = buildReleaseCandidateExecutionRows().singleWhere(
    (candidate) => candidate.executionId == executionId,
  );
  return VerifiedCandidateSet(
    candidateDirectory: candidateDirectory,
    candidateId: candidateId,
    sdkRef: sdkRef,
    digest: digest,
    artifactDigests: <String, String>{
      for (var index = 0; index < row.targets.length; index++)
        row.targets[index].releaseAssetFileName: List<String>.filled(
          64,
          (index + 1).toRadixString(16),
        ).join(),
    },
    artifactFiles: <String, File>{
      for (final target in row.targets)
        target.releaseAssetFileName: File(
          p.join(candidateDirectory.path, target.releaseAssetFileName),
        ),
    },
  );
}

Future<void> _writeMacosEntitlementFixtures(String fixturePath) async {
  final runnerDirectory = Directory(p.join(fixturePath, 'macos', 'Runner'));
  await runnerDirectory.create(recursive: true);
  for (final name in <String>[
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    await File(p.join(runnerDirectory.path, name)).writeAsString('''
<plist version="1.0">
<dict>
</dict>
</plist>
''');
  }
}

const _runtimeProofMarkerLine =
    'flutter: NEXA_HTTP_RUNTIME_PROOF '
    '{"request_completed":true,"callback_received":true,'
    '"body_consumed":true,"body_released":true,"client_closed":true}';
