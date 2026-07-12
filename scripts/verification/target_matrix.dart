import 'dart:convert';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import 'model.dart';

final class IntegrationExecutionRow {
  const IntegrationExecutionRow({
    required this.executionId,
    required this.runner,
    required this.targets,
  });

  final VerificationExecutionId executionId;
  final VerificationRunner runner;
  final List<NexaHttpNativeTarget> targets;
}

List<IntegrationExecutionRow> buildIntegrationExecutionRows() {
  final androidTargets = nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == 'android')
      .toList(growable: false);
  final appleTargets = nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == 'ios' || target.targetOS == 'macos')
      .toList(growable: false);
  final windowsTargets = nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == 'windows')
      .toList(growable: false);

  final rows = <IntegrationExecutionRow>[
    IntegrationExecutionRow(
      executionId: const VerificationExecutionId('android-linux'),
      runner: const VerificationRunner('ubuntu-latest'),
      targets: androidTargets,
    ),
    IntegrationExecutionRow(
      executionId: const VerificationExecutionId('apple-macos'),
      runner: const VerificationRunner('macos-14'),
      targets: appleTargets,
    ),
    IntegrationExecutionRow(
      executionId: const VerificationExecutionId('windows-x64'),
      runner: const VerificationRunner('windows-latest'),
      targets: windowsTargets,
    ),
  ];
  validateIntegrationExecutionRows(rows);
  return rows;
}

String buildActionsMatrixJson(VerificationSuiteId suiteId) {
  if (suiteId == VerificationSuiteId.verifyStatic) {
    return jsonEncode(<String, Object?>{
      'include': <Map<String, Object?>>[
        <String, Object?>{
          'suite': suiteId.value,
          'execution_id': 'static-linux',
          'runner': 'ubuntu-latest',
          'logical_targets': <Object?>[],
        },
      ],
    });
  }
  if (suiteId == VerificationSuiteId.verifyIntegration) {
    return jsonEncode(<String, Object?>{
      'include': <Map<String, Object?>>[
        for (final row in buildIntegrationExecutionRows())
          <String, Object?>{
            'suite': suiteId.value,
            'execution_id': row.executionId.value,
            'runner': row.runner.value,
            'logical_targets': row.targets
                .map(_targetKey)
                .toList(growable: false),
          },
      ],
    });
  }
  if (suiteId == VerificationSuiteId.verifyReleaseCandidate) {
    final rows = buildReleaseCandidateExecutionRows();
    return jsonEncode(<String, Object?>{
      'include': <Map<String, Object?>>[
        for (final row in rows)
          <String, Object?>{
            'suite': suiteId.value,
            'execution_id': row.executionId.value,
            'runner': row.runner.value,
            'logical_targets': row.targets
                .map(_targetKey)
                .toList(growable: false),
          },
      ],
    });
  }
  throw StateError('Actions matrix is not implemented for suite $suiteId');
}

List<IntegrationExecutionRow> buildReleaseCandidateExecutionRows() {
  final rows = <IntegrationExecutionRow>[
    _platformCandidateRow(
      executionId: 'candidate-android',
      runner: 'ubuntu-latest',
      targetOS: 'android',
    ),
    _platformCandidateRow(
      executionId: 'candidate-ios',
      runner: 'macos-14',
      targetOS: 'ios',
    ),
    _platformCandidateRow(
      executionId: 'candidate-macos',
      runner: 'macos-14',
      targetOS: 'macos',
    ),
    _platformCandidateRow(
      executionId: 'candidate-windows',
      runner: 'windows-latest',
      targetOS: 'windows',
    ),
  ];
  validateIntegrationExecutionRows(rows);
  return rows;
}

IntegrationExecutionRow _platformCandidateRow({
  required String executionId,
  required String runner,
  required String targetOS,
}) {
  return IntegrationExecutionRow(
    executionId: VerificationExecutionId(executionId),
    runner: VerificationRunner(runner),
    targets: nexaHttpSupportedNativeTargets
        .where((target) => target.targetOS == targetOS)
        .toList(growable: false),
  );
}

void validateIntegrationExecutionRows(List<IntegrationExecutionRow> rows) {
  final coveredTargetKeys = <String>{};
  for (final row in rows) {
    for (final target in row.targets) {
      final key = _targetKey(target);
      if (!coveredTargetKeys.add(key)) {
        throw StateError('Native target is covered more than once: $key');
      }
    }
  }

  final canonicalTargetKeys = nexaHttpSupportedNativeTargets
      .map(_targetKey)
      .toSet();
  if (!coveredTargetKeys.containsAll(canonicalTargetKeys)) {
    final missing = canonicalTargetKeys.difference(coveredTargetKeys).toList()
      ..sort();
    throw StateError('Native targets have no execution coverage: $missing');
  }
  if (!canonicalTargetKeys.containsAll(coveredTargetKeys)) {
    final unknown = coveredTargetKeys.difference(canonicalTargetKeys).toList()
      ..sort();
    throw StateError('Execution rows contain unknown native targets: $unknown');
  }
}

String _targetKey(NexaHttpNativeTarget target) {
  return <String>[
    target.targetOS,
    target.targetArchitecture,
    target.targetSdk ?? '',
  ].join(':');
}
