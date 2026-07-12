import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../../scripts/verification/model.dart';
import '../../scripts/verification/report.dart';
import '../../scripts/verification/target_matrix.dart';

void main() {
  test('aggregate rejects an integration row with missing native proofs', () {
    expect(
      () => verifyAggregateCoverage(
        suiteId: VerificationSuiteId.verifyIntegration,
        expectedExecutionIds: const <VerificationExecutionId>[
          VerificationExecutionId('android-linux'),
          VerificationExecutionId('apple-macos'),
          VerificationExecutionId('windows-x64'),
        ],
        expectedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
        ],
        reports: <VerificationCoverageReport>[
          _emptyIntegrationReport('android-linux'),
          _emptyIntegrationReport('apple-macos'),
          _emptyIntegrationReport('windows-x64'),
        ],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('aggregate rejects a runtime payload digest mismatch', () {
    final reports = _completeNativeProofReports(
      VerificationSuiteId.verifyIntegration,
      mismatchedRuntimePlatform: 'android',
    );

    expect(
      () => _verifyNativeProofAggregate(
        VerificationSuiteId.verifyIntegration,
        reports,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('aggregate keeps Apple raw digests while matching stable identity', () {
    final reports = _completeNativeProofReports(
      VerificationSuiteId.verifyIntegration,
    );
    final apple = reports.singleWhere(
      (report) => report.executionId.value == 'apple-macos',
    );
    final runtimeProofs = <VerificationRuntimePayloadProof>[
      for (final proof in apple.runtimePayloadProofs)
        VerificationRuntimePayloadProof(
          target: proof.target,
          nativeAssetId: proof.nativeAssetId,
          absolutePackagedFile: proof.absolutePackagedFile,
          sha256:
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          identitySha256: proof.identitySha256,
          payloadCount: proof.payloadCount,
          requestCompleted: proof.requestCompleted,
          callbackReceived: proof.callbackReceived,
          bodyConsumed: proof.bodyConsumed,
          bodyReleased: proof.bodyReleased,
          clientClosed: proof.clientClosed,
        ),
    ];
    _replaceReport(reports, apple, runtimePayloadProofs: runtimeProofs);

    expect(
      () => _verifyNativeProofAggregate(
        VerificationSuiteId.verifyIntegration,
        reports,
      ),
      returnsNormally,
    );
  });

  test('aggregate rejects a missing macOS runtime proof in the Apple row', () {
    final reports = _completeNativeProofReports(
      VerificationSuiteId.verifyIntegration,
    );
    final apple = reports.singleWhere(
      (report) => report.executionId.value == 'apple-macos',
    );
    _replaceReport(
      reports,
      apple,
      runtimePayloadProofs: apple.runtimePayloadProofs
          .where((proof) => proof.target.targetOS != 'macos')
          .toList(growable: false),
    );

    expect(
      () => _verifyNativeProofAggregate(
        VerificationSuiteId.verifyIntegration,
        reports,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('aggregate rejects a duplicate prepared target tuple', () {
    final reports = _completeNativeProofReports(
      VerificationSuiteId.verifyIntegration,
    );
    final android = reports.singleWhere(
      (report) => report.executionId.value == 'android-linux',
    );
    _replaceReport(
      reports,
      android,
      preparedArtifactProofs: <VerificationPreparedArtifactProof>[
        android.preparedArtifactProofs.first,
        android.preparedArtifactProofs.first,
        android.preparedArtifactProofs.last,
      ],
    );

    expect(
      () => _verifyNativeProofAggregate(
        VerificationSuiteId.verifyIntegration,
        reports,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('aggregate rejects an unknown prepared target tuple', () {
    final reports = _completeNativeProofReports(
      VerificationSuiteId.verifyIntegration,
    );
    final windows = reports.singleWhere(
      (report) => report.executionId.value == 'windows-x64',
    );
    final original = windows.preparedArtifactProofs.single;
    _replaceReport(
      reports,
      windows,
      preparedArtifactProofs: <VerificationPreparedArtifactProof>[
        VerificationPreparedArtifactProof(
          target: VerificationNativeTargetTuple(
            targetOS: 'windows',
            targetArchitecture: 'arm64',
            targetSdk: null,
            rustTarget: 'aarch64-pc-windows-msvc',
          ),
          nativeAssetId: original.nativeAssetId,
          absolutePreparedFile: original.absolutePreparedFile,
          sha256: original.sha256,
          identitySha256: original.identitySha256,
          sourceIdentity: original.sourceIdentity,
        ),
      ],
    );

    expect(
      () => _verifyNativeProofAggregate(
        VerificationSuiteId.verifyIntegration,
        reports,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('aggregate accepts complete canonical native proof coverage', () {
    for (final suiteId in <VerificationSuiteId>[
      VerificationSuiteId.verifyIntegration,
      VerificationSuiteId.verifyReleaseCandidate,
    ]) {
      final reports = _completeNativeProofReports(suiteId);
      expect(
        () => _verifyNativeProofAggregate(suiteId, reports),
        returnsNormally,
      );
    }
  });

  test('aggregate rejects native proofs in a static report', () {
    final nativeReport = _completeNativeProofReports(
      VerificationSuiteId.verifyIntegration,
    ).first;
    final staticReport = VerificationCoverageReport(
      suiteId: VerificationSuiteId.verifyStatic,
      executionId: const VerificationExecutionId('static-linux'),
      plannedCheckIds: const <VerificationCheckId>[
        VerificationCheckId('workspace-dart-analyze'),
      ],
      completedCheckIds: const <VerificationCheckId>[
        VerificationCheckId('workspace-dart-analyze'),
      ],
      status: VerificationCoverageStatus.passed,
      preparedArtifactProofs: nativeReport.preparedArtifactProofs,
      runtimePayloadProofs: nativeReport.runtimePayloadProofs,
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
        reports: <VerificationCoverageReport>[staticReport],
      ),
      throwsA(isA<StateError>()),
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

  test('coverage report JSON preserves the v2 native proof contract', () {
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
      preparedArtifactProofs: <VerificationPreparedArtifactProof>[
        VerificationPreparedArtifactProof(
          target: VerificationNativeTargetTuple(
            targetOS: 'android',
            targetArchitecture: 'x64',
            targetSdk: null,
            rustTarget: 'x86_64-linux-android',
          ),
          nativeAssetId:
              'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
          absolutePreparedFile: '/tmp/nexa_http-native-android-x86_64.so',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          identitySha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          sourceIdentity: 'workspace',
        ),
      ],
      runtimePayloadProofs: <VerificationRuntimePayloadProof>[
        VerificationRuntimePayloadProof(
          target: VerificationNativeTargetTuple(
            targetOS: 'android',
            targetArchitecture: 'x64',
            targetSdk: null,
            rustTarget: 'x86_64-linux-android',
          ),
          nativeAssetId:
              'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
          absolutePackagedFile: '/tmp/app/lib/x86_64/libnexa_http_native.so',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          identitySha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          payloadCount: 1,
          requestCompleted: true,
          callbackReceived: true,
          bodyConsumed: true,
          bodyReleased: true,
          clientClosed: true,
        ),
      ],
    );

    expect(VerificationCoverageReport.fromJson(report.toJson()).toJson(), {
      'schema_version': 2,
      'suite_id': 'verify-static',
      'execution_id': 'static-linux',
      'planned_check_ids': <String>['workspace-dart-analyze'],
      'completed_check_ids': <String>['workspace-dart-analyze'],
      'status': 'passed',
      'prepared_artifacts': <Map<String, Object?>>[
        <String, Object?>{
          'target': <String, Object?>{
            'target_os': 'android',
            'target_architecture': 'x64',
            'target_sdk': null,
            'rust_target': 'x86_64-linux-android',
          },
          'native_asset_id':
              'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
          'absolute_prepared_file': '/tmp/nexa_http-native-android-x86_64.so',
          'sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'identity_sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'source_identity': 'workspace',
        },
      ],
      'runtime_payloads': <Map<String, Object?>>[
        <String, Object?>{
          'target': <String, Object?>{
            'target_os': 'android',
            'target_architecture': 'x64',
            'target_sdk': null,
            'rust_target': 'x86_64-linux-android',
          },
          'native_asset_id':
              'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
          'absolute_packaged_file':
              '/tmp/app/lib/x86_64/libnexa_http_native.so',
          'sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'identity_sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'payload_count': 1,
          'request_completed': true,
          'callback_received': true,
          'body_consumed': true,
          'body_released': true,
          'client_closed': true,
        },
      ],
    });
  });

  test('coverage report rejects the removed v1 schema', () {
    expect(
      () => VerificationCoverageReport.fromJson(<String, Object?>{
        'schema_version': 1,
        'suite_id': 'verify-integration',
        'execution_id': 'android-linux',
        'planned_check_ids': <String>['native-build'],
        'completed_check_ids': <String>['native-build'],
        'status': 'passed',
      }),
      throwsFormatException,
    );
  });

  test('coverage report rejects missing native proof collections', () {
    expect(
      () => VerificationCoverageReport.fromJson(<String, Object?>{
        'schema_version': 2,
        'suite_id': 'verify-integration',
        'execution_id': 'android-linux',
        'planned_check_ids': <String>['native-build'],
        'completed_check_ids': <String>['native-build'],
        'status': 'passed',
        'prepared_artifacts': <Object?>[],
      }),
      throwsFormatException,
    );
  });

  test('coverage report rejects an invalid prepared artifact digest', () {
    final json = _validV2ProofReportJson();
    final preparedArtifacts = json['prepared_artifacts']! as List<Object?>;
    final preparedArtifact = preparedArtifacts.single! as Map<String, Object?>;
    preparedArtifact['sha256'] = 'not-a-sha256';

    expect(
      () => VerificationCoverageReport.fromJson(json),
      throwsFormatException,
    );
  });

  test('coverage report rejects relative native proof paths', () {
    final json = _validV2ProofReportJson();
    final preparedArtifacts = json['prepared_artifacts']! as List<Object?>;
    final preparedArtifact = preparedArtifacts.single! as Map<String, Object?>;
    preparedArtifact['absolute_prepared_file'] = 'relative/native.so';

    expect(
      () => VerificationCoverageReport.fromJson(json),
      throwsFormatException,
    );
  });

  test('coverage report rejects a missing prepared artifact field', () {
    final json = _validV2ProofReportJson();
    final preparedArtifacts = json['prepared_artifacts']! as List<Object?>;
    final preparedArtifact = preparedArtifacts.single! as Map<String, Object?>;
    preparedArtifact.remove('native_asset_id');

    expect(
      () => VerificationCoverageReport.fromJson(json),
      throwsFormatException,
    );
  });

  test('coverage report rejects a non-unique runtime payload proof', () {
    final json = _validV2ProofReportJson();
    final runtimePayloads = json['runtime_payloads']! as List<Object?>;
    final runtimePayload = runtimePayloads.single! as Map<String, Object?>;
    runtimePayload['payload_count'] = 2;

    expect(
      () => VerificationCoverageReport.fromJson(json),
      throwsFormatException,
    );
  });

  test('coverage report rejects an incomplete runtime lifecycle proof', () {
    final json = _validV2ProofReportJson();
    final runtimePayloads = json['runtime_payloads']! as List<Object?>;
    final runtimePayload = runtimePayloads.single! as Map<String, Object?>;
    runtimePayload['body_released'] = false;

    expect(
      () => VerificationCoverageReport.fromJson(json),
      throwsFormatException,
    );
  });
}

VerificationCoverageReport _emptyIntegrationReport(String executionId) {
  return VerificationCoverageReport(
    suiteId: VerificationSuiteId.verifyIntegration,
    executionId: VerificationExecutionId(executionId),
    plannedCheckIds: const <VerificationCheckId>[
      VerificationCheckId('native-build'),
    ],
    completedCheckIds: const <VerificationCheckId>[
      VerificationCheckId('native-build'),
    ],
    status: VerificationCoverageStatus.passed,
  );
}

List<VerificationCoverageReport> _completeNativeProofReports(
  VerificationSuiteId suiteId, {
  String? mismatchedRuntimePlatform,
}) {
  final rows = suiteId == VerificationSuiteId.verifyIntegration
      ? buildIntegrationExecutionRows()
      : buildReleaseCandidateExecutionRows();
  return <VerificationCoverageReport>[
    for (final row in rows)
      VerificationCoverageReport(
        suiteId: suiteId,
        executionId: row.executionId,
        plannedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
        ],
        completedCheckIds: const <VerificationCheckId>[
          VerificationCheckId('native-build'),
        ],
        status: VerificationCoverageStatus.passed,
        preparedArtifactProofs: <VerificationPreparedArtifactProof>[
          for (var index = 0; index < row.targets.length; index++)
            VerificationPreparedArtifactProof(
              target: _proofTuple(row.targets[index]),
              nativeAssetId: row.targets[index].nativeAssetId,
              absolutePreparedFile:
                  '/tmp/prepared/${row.targets[index].releaseAssetFileName}',
              sha256: _digestForTarget(row.targets[index].rustTargetTriple),
              identitySha256: _digestForTarget(
                row.targets[index].rustTargetTriple,
              ),
              sourceIdentity: 'workspace',
            ),
        ],
        runtimePayloadProofs: <VerificationRuntimePayloadProof>[
          for (final targetOS
              in row.targets.map((target) => target.targetOS).toSet())
            _runtimeProof(
              row.targets.firstWhere((target) => target.targetOS == targetOS),
              digestMismatch: targetOS == mismatchedRuntimePlatform,
            ),
        ],
      ),
  ];
}

VerificationNativeTargetTuple _proofTuple(NexaHttpNativeTarget target) {
  return VerificationNativeTargetTuple(
    targetOS: target.targetOS,
    targetArchitecture: target.targetArchitecture,
    targetSdk: target.targetSdk,
    rustTarget: target.rustTargetTriple,
  );
}

VerificationRuntimePayloadProof _runtimeProof(
  NexaHttpNativeTarget target, {
  required bool digestMismatch,
}) {
  return VerificationRuntimePayloadProof(
    target: _proofTuple(target),
    nativeAssetId: target.nativeAssetId,
    absolutePackagedFile: '/tmp/packaged/${target.releaseAssetFileName}',
    sha256: _digestForTarget(target.rustTargetTriple),
    identitySha256: digestMismatch
        ? 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
        : _digestForTarget(target.rustTargetTriple),
    payloadCount: 1,
    requestCompleted: true,
    callbackReceived: true,
    bodyConsumed: true,
    bodyReleased: true,
    clientClosed: true,
  );
}

String _digestForTarget(String rustTarget) {
  final code = rustTarget.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return code.toRadixString(16).padLeft(64, '0');
}

void _verifyNativeProofAggregate(
  VerificationSuiteId suiteId,
  List<VerificationCoverageReport> reports,
) {
  verifyAggregateCoverage(
    suiteId: suiteId,
    expectedExecutionIds: reports
        .map((report) => report.executionId)
        .toList(growable: false),
    expectedCheckIds: const <VerificationCheckId>[
      VerificationCheckId('native-build'),
    ],
    reports: reports,
  );
}

void _replaceReport(
  List<VerificationCoverageReport> reports,
  VerificationCoverageReport original, {
  List<VerificationPreparedArtifactProof>? preparedArtifactProofs,
  List<VerificationRuntimePayloadProof>? runtimePayloadProofs,
}) {
  reports[reports.indexOf(original)] = VerificationCoverageReport(
    suiteId: original.suiteId,
    executionId: original.executionId,
    plannedCheckIds: original.plannedCheckIds,
    completedCheckIds: original.completedCheckIds,
    status: original.status,
    preparedArtifactProofs:
        preparedArtifactProofs ?? original.preparedArtifactProofs,
    runtimePayloadProofs: runtimePayloadProofs ?? original.runtimePayloadProofs,
  );
}

Map<String, Object?> _validV2ProofReportJson() => <String, Object?>{
  'schema_version': 2,
  'suite_id': 'verify-integration',
  'execution_id': 'android-linux',
  'planned_check_ids': <String>['native-build'],
  'completed_check_ids': <String>['native-build'],
  'status': 'passed',
  'prepared_artifacts': <Object?>[
    <String, Object?>{
      'target': <String, Object?>{
        'target_os': 'android',
        'target_architecture': 'x64',
        'target_sdk': null,
        'rust_target': 'x86_64-linux-android',
      },
      'native_asset_id':
          'package:nexa_http_native_android/src/native/'
          'nexa_http_native_ffi.dart',
      'absolute_prepared_file': '/tmp/nexa_http-native-android-x86_64.so',
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'identity_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'source_identity': 'workspace',
    },
  ],
  'runtime_payloads': <Object?>[
    <String, Object?>{
      'target': <String, Object?>{
        'target_os': 'android',
        'target_architecture': 'x64',
        'target_sdk': null,
        'rust_target': 'x86_64-linux-android',
      },
      'native_asset_id':
          'package:nexa_http_native_android/src/native/'
          'nexa_http_native_ffi.dart',
      'absolute_packaged_file': '/tmp/app/lib/x86_64/libnexa_http_native.so',
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'identity_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'payload_count': 1,
      'request_completed': true,
      'callback_received': true,
      'body_consumed': true,
      'body_released': true,
      'client_closed': true,
    },
  ],
};
