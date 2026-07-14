import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import 'model.dart';
import 'target_matrix.dart';

enum VerificationCoverageStatus { passed, failed }

final class VerificationNativeTargetTuple {
  VerificationNativeTargetTuple({
    required this.targetOS,
    required this.targetArchitecture,
    required this.targetSdk,
    required this.rustTarget,
  });

  factory VerificationNativeTargetTuple.fromJson(Map<String, Object?> json) {
    return VerificationNativeTargetTuple(
      targetOS: _requiredNonEmptyString(json, 'target_os'),
      targetArchitecture: _requiredNonEmptyString(json, 'target_architecture'),
      targetSdk: _requiredNullableString(json, 'target_sdk'),
      rustTarget: _requiredNonEmptyString(json, 'rust_target'),
    );
  }

  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String rustTarget;

  Map<String, Object?> toJson() => <String, Object?>{
    'target_os': targetOS,
    'target_architecture': targetArchitecture,
    'target_sdk': targetSdk,
    'rust_target': rustTarget,
  };
}

final class VerificationPreparedArtifactProof {
  VerificationPreparedArtifactProof({
    required this.target,
    required this.nativeAssetId,
    required this.absolutePreparedFile,
    required this.sha256,
    required this.identitySha256,
    required this.sourceIdentity,
  });

  factory VerificationPreparedArtifactProof.fromJson(
    Map<String, Object?> json,
  ) {
    return VerificationPreparedArtifactProof(
      target: VerificationNativeTargetTuple.fromJson(
        _requiredMap(json, 'target'),
      ),
      nativeAssetId: _requiredNonEmptyString(json, 'native_asset_id'),
      absolutePreparedFile: _requiredAbsolutePath(
        json,
        'absolute_prepared_file',
      ),
      sha256: _parseSha256(json['sha256'], field: 'prepared_artifacts.sha256'),
      identitySha256: _parseSha256(
        json['identity_sha256'],
        field: 'prepared_artifacts.identity_sha256',
      ),
      sourceIdentity: _requiredNonEmptyString(json, 'source_identity'),
    );
  }

  final VerificationNativeTargetTuple target;
  final String nativeAssetId;
  final String absolutePreparedFile;
  final String sha256;
  final String identitySha256;
  final String sourceIdentity;

  Map<String, Object?> toJson() => <String, Object?>{
    'target': target.toJson(),
    'native_asset_id': nativeAssetId,
    'absolute_prepared_file': absolutePreparedFile,
    'sha256': sha256,
    'identity_sha256': identitySha256,
    'source_identity': sourceIdentity,
  };
}

final class VerificationRuntimePayloadProof {
  VerificationRuntimePayloadProof({
    required this.target,
    required this.nativeAssetId,
    required this.absolutePackagedFile,
    required this.sha256,
    required this.identitySha256,
    required this.payloadCount,
    required this.requestCompleted,
    required this.callbackReceived,
    required this.bodyConsumed,
    required this.bodyReleased,
    required this.clientClosed,
  });

  factory VerificationRuntimePayloadProof.fromJson(Map<String, Object?> json) {
    return VerificationRuntimePayloadProof(
      target: VerificationNativeTargetTuple.fromJson(
        _requiredMap(json, 'target'),
      ),
      nativeAssetId: _requiredNonEmptyString(json, 'native_asset_id'),
      absolutePackagedFile: _requiredAbsolutePath(
        json,
        'absolute_packaged_file',
      ),
      sha256: _parseSha256(json['sha256'], field: 'runtime_payloads.sha256'),
      identitySha256: _parseSha256(
        json['identity_sha256'],
        field: 'runtime_payloads.identity_sha256',
      ),
      payloadCount: _requiredUniquePayloadCount(json),
      requestCompleted: _requiredTrue(json, 'request_completed'),
      callbackReceived: _requiredTrue(json, 'callback_received'),
      bodyConsumed: _requiredTrue(json, 'body_consumed'),
      bodyReleased: _requiredTrue(json, 'body_released'),
      clientClosed: _requiredTrue(json, 'client_closed'),
    );
  }

  final VerificationNativeTargetTuple target;
  final String nativeAssetId;
  final String absolutePackagedFile;
  final String sha256;
  final String identitySha256;
  final int payloadCount;
  final bool requestCompleted;
  final bool callbackReceived;
  final bool bodyConsumed;
  final bool bodyReleased;
  final bool clientClosed;

  Map<String, Object?> toJson() => <String, Object?>{
    'target': target.toJson(),
    'native_asset_id': nativeAssetId,
    'absolute_packaged_file': absolutePackagedFile,
    'sha256': sha256,
    'identity_sha256': identitySha256,
    'payload_count': payloadCount,
    'request_completed': requestCompleted,
    'callback_received': callbackReceived,
    'body_consumed': bodyConsumed,
    'body_released': bodyReleased,
    'client_closed': clientClosed,
  };
}

final class VerificationCoverageReport {
  VerificationCoverageReport({
    required this.suiteId,
    required this.executionId,
    required List<VerificationCheckId> plannedCheckIds,
    required List<VerificationCheckId> completedCheckIds,
    required this.status,
    List<VerificationPreparedArtifactProof> preparedArtifactProofs =
        const <VerificationPreparedArtifactProof>[],
    List<VerificationRuntimePayloadProof> runtimePayloadProofs =
        const <VerificationRuntimePayloadProof>[],
  }) : plannedCheckIds = List<VerificationCheckId>.unmodifiable(
         plannedCheckIds,
       ),
       completedCheckIds = List<VerificationCheckId>.unmodifiable(
         completedCheckIds,
       ),
       preparedArtifactProofs =
           List<VerificationPreparedArtifactProof>.unmodifiable(
             preparedArtifactProofs,
           ),
       runtimePayloadProofs =
           List<VerificationRuntimePayloadProof>.unmodifiable(
             runtimePayloadProofs,
           );

  factory VerificationCoverageReport.fromJson(Map<String, Object?> json) {
    if (json['schema_version'] != 2 ||
        json['suite_id'] is! String ||
        json['execution_id'] is! String ||
        json['planned_check_ids'] is! List<Object?> ||
        json['completed_check_ids'] is! List<Object?> ||
        json['status'] is! String ||
        json['prepared_artifacts'] is! List<Object?> ||
        json['runtime_payloads'] is! List<Object?>) {
      throw const FormatException('Invalid verification coverage report');
    }
    List<VerificationCheckId> parseCheckIds(String key) {
      final values = json[key]! as List<Object?>;
      if (values.any((value) => value is! String)) {
        throw FormatException('Invalid $key in verification coverage report');
      }
      return values
          .cast<String>()
          .map(VerificationCheckId.new)
          .toList(growable: false);
    }

    final status = switch (json['status']) {
      'passed' => VerificationCoverageStatus.passed,
      'failed' => VerificationCoverageStatus.failed,
      _ => throw const FormatException(
        'Invalid status in verification coverage report',
      ),
    };
    return VerificationCoverageReport(
      suiteId: VerificationSuiteId(json['suite_id']! as String),
      executionId: VerificationExecutionId(json['execution_id']! as String),
      plannedCheckIds: parseCheckIds('planned_check_ids'),
      completedCheckIds: parseCheckIds('completed_check_ids'),
      status: status,
      preparedArtifactProofs: _parseProofList(
        json['prepared_artifacts']! as List<Object?>,
        VerificationPreparedArtifactProof.fromJson,
      ),
      runtimePayloadProofs: _parseProofList(
        json['runtime_payloads']! as List<Object?>,
        VerificationRuntimePayloadProof.fromJson,
      ),
    );
  }

  final VerificationSuiteId suiteId;
  final VerificationExecutionId executionId;
  final List<VerificationCheckId> plannedCheckIds;
  final List<VerificationCheckId> completedCheckIds;
  final VerificationCoverageStatus status;
  final List<VerificationPreparedArtifactProof> preparedArtifactProofs;
  final List<VerificationRuntimePayloadProof> runtimePayloadProofs;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': 2,
    'suite_id': suiteId.value,
    'execution_id': executionId.value,
    'planned_check_ids': plannedCheckIds
        .map((checkId) => checkId.value)
        .toList(growable: false),
    'completed_check_ids': completedCheckIds
        .map((checkId) => checkId.value)
        .toList(growable: false),
    'status': status.name,
    'prepared_artifacts': preparedArtifactProofs
        .map((proof) => proof.toJson())
        .toList(growable: false),
    'runtime_payloads': runtimePayloadProofs
        .map((proof) => proof.toJson())
        .toList(growable: false),
  };
}

List<T> _parseProofList<T>(
  List<Object?> values,
  T Function(Map<String, Object?> json) parse,
) {
  return <T>[
    for (final value in values)
      if (value is Map)
        parse(value.cast<String, Object?>())
      else
        throw const FormatException(
          'Invalid proof entry in verification coverage report',
        ),
  ];
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! Map) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value.cast<String, Object?>();
}

String _requiredNonEmptyString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value;
}

String _requiredAbsolutePath(Map<String, Object?> json, String field) {
  final value = _requiredNonEmptyString(json, field);
  if (!p.posix.isAbsolute(value) && !p.windows.isAbsolute(value)) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value;
}

String? _requiredNullableString(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) {
    throw FormatException('Missing $field in verification coverage report');
  }
  final value = json[field];
  if (value != null && (value is! String || value.trim().isEmpty)) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value as String?;
}

int _requiredInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value;
}

int _requiredUniquePayloadCount(Map<String, Object?> json) {
  final value = _requiredInt(json, 'payload_count');
  if (value != 1) {
    throw const FormatException(
      'Invalid payload_count in verification coverage report',
    );
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! bool) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value;
}

bool _requiredTrue(Map<String, Object?> json, String field) {
  final value = _requiredBool(json, field);
  if (!value) {
    throw FormatException('Incomplete $field in verification coverage report');
  }
  return value;
}

String _parseSha256(Object? value, {required String field}) {
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('Invalid $field in verification coverage report');
  }
  return value;
}

void verifyAggregateCoverage({
  required VerificationSuiteId suiteId,
  required List<VerificationExecutionId> expectedExecutionIds,
  required List<VerificationCheckId> expectedCheckIds,
  required List<VerificationCoverageReport> reports,
}) {
  final reportsByExecution =
      <VerificationExecutionId, VerificationCoverageReport>{};
  for (final report in reports) {
    if (report.suiteId != suiteId) {
      throw StateError(
        'Coverage report suite mismatch: expected=$suiteId actual=${report.suiteId}',
      );
    }
    if (reportsByExecution.containsKey(report.executionId)) {
      throw StateError(
        'Duplicate coverage report for execution ${report.executionId}',
      );
    }
    reportsByExecution[report.executionId] = report;
    if (report.status != VerificationCoverageStatus.passed) {
      throw StateError('Coverage report failed for ${report.executionId}');
    }
  }

  final expectedExecutions = expectedExecutionIds.toSet();
  final actualExecutions = reportsByExecution.keys.toSet();
  if (actualExecutions.length != expectedExecutions.length ||
      !actualExecutions.containsAll(expectedExecutions)) {
    throw StateError(
      'Coverage execution mismatch: expected=$expectedExecutions actual=$actualExecutions',
    );
  }

  final expectedChecks = expectedCheckIds.toSet();
  for (final executionId in expectedExecutionIds) {
    final report = reportsByExecution[executionId]!;
    final plannedChecks = report.plannedCheckIds.toSet();
    final completedChecks = report.completedCheckIds.toSet();
    if (plannedChecks.length != expectedChecks.length ||
        !plannedChecks.containsAll(expectedChecks) ||
        completedChecks.length != expectedChecks.length ||
        !completedChecks.containsAll(expectedChecks)) {
      throw StateError(
        'Coverage check mismatch for $executionId: '
        'expected=$expectedChecks planned=$plannedChecks completed=$completedChecks',
      );
    }
  }

  _verifyAggregateNativeProofCoverage(
    suiteId: suiteId,
    reportsByExecution: reportsByExecution,
  );
}

void _verifyAggregateNativeProofCoverage({
  required VerificationSuiteId suiteId,
  required Map<VerificationExecutionId, VerificationCoverageReport>
  reportsByExecution,
}) {
  if (suiteId == VerificationSuiteId.verifyStatic) {
    for (final report in reportsByExecution.values) {
      if (report.preparedArtifactProofs.isNotEmpty ||
          report.runtimePayloadProofs.isNotEmpty) {
        throw StateError(
          'Static coverage report must not contain native proof',
        );
      }
    }
    return;
  }

  final rows = switch (suiteId) {
    VerificationSuiteId.verifyIntegration => buildIntegrationExecutionRows(),
    VerificationSuiteId.verifyReleaseCandidate =>
      buildReleaseCandidateExecutionRows(),
    _ => throw StateError('Unsupported native proof suite: $suiteId'),
  };
  final canonicalExecutionIds = rows.map((row) => row.executionId).toSet();
  final reportedExecutionIds = reportsByExecution.keys.toSet();
  if (reportedExecutionIds.length != canonicalExecutionIds.length ||
      !reportedExecutionIds.containsAll(canonicalExecutionIds)) {
    throw StateError(
      'Native proof execution mismatch: '
      'expected=$canonicalExecutionIds actual=$reportedExecutionIds',
    );
  }
  final aggregatePreparedTargets = <String>{};
  final aggregateRuntimePlatforms = <String>{};
  String? releaseCandidateSourceIdentity;
  for (final row in rows) {
    final report = reportsByExecution[row.executionId];
    if (report == null) {
      throw StateError('Missing native proof report for ${row.executionId}');
    }
    if (report.preparedArtifactProofs.length != row.targets.length) {
      throw StateError(
        'Prepared proof count mismatch for ${row.executionId}: '
        'expected=${row.targets.length} '
        'actual=${report.preparedArtifactProofs.length}',
      );
    }
    final expectedTargets = <String, NexaHttpNativeTarget>{
      for (final target in row.targets) _canonicalTargetKey(target): target,
    };
    final preparedByTarget = <String, VerificationPreparedArtifactProof>{};
    for (final proof in report.preparedArtifactProofs) {
      final key = _proofTargetKey(proof.target);
      final target = expectedTargets[key];
      if (target == null) {
        throw StateError(
          'Unknown prepared proof target for ${row.executionId}: $key',
        );
      }
      if (proof.nativeAssetId != target.nativeAssetId) {
        throw StateError(
          'Prepared proof Native Asset ID mismatch for $key: '
          'expected=${target.nativeAssetId} actual=${proof.nativeAssetId}',
        );
      }
      if (suiteId == VerificationSuiteId.verifyReleaseCandidate) {
        if (!RegExp(
          r'^candidate:gha:[1-9][0-9]*:[1-9][0-9]*:[0-9a-f]{64}$',
        ).hasMatch(proof.sourceIdentity)) {
          throw StateError(
            'Invalid release candidate source identity for '
            '${row.executionId}: ${proof.sourceIdentity}',
          );
        }
        final expectedSourceIdentity = releaseCandidateSourceIdentity;
        if (expectedSourceIdentity == null) {
          releaseCandidateSourceIdentity = proof.sourceIdentity;
        } else if (proof.sourceIdentity != expectedSourceIdentity) {
          throw StateError(
            'Release candidate source identity mismatch: '
            'expected=$expectedSourceIdentity actual=${proof.sourceIdentity}',
          );
        }
      }
      if (preparedByTarget.containsKey(key)) {
        throw StateError(
          'Duplicate prepared proof target for ${row.executionId}: $key',
        );
      }
      preparedByTarget[key] = proof;
      if (!aggregatePreparedTargets.add(key)) {
        throw StateError('Duplicate aggregate prepared target: $key');
      }
    }
    if (preparedByTarget.length != expectedTargets.length) {
      throw StateError(
        'Prepared proof target coverage mismatch for ${row.executionId}',
      );
    }
    final expectedRuntimePlatforms = row.targets
        .map((target) => target.targetOS)
        .toSet();
    if (report.runtimePayloadProofs.length != expectedRuntimePlatforms.length) {
      throw StateError(
        'Runtime proof count mismatch for ${row.executionId}: '
        'expected=${expectedRuntimePlatforms.length} '
        'actual=${report.runtimePayloadProofs.length}',
      );
    }
    final runtimePlatforms = <String>{};
    for (final proof in report.runtimePayloadProofs) {
      if (proof.payloadCount != 1 ||
          !proof.requestCompleted ||
          !proof.callbackReceived ||
          !proof.bodyConsumed ||
          !proof.bodyReleased ||
          !proof.clientClosed) {
        throw StateError(
          'Incomplete runtime payload lifecycle proof for '
          '${row.executionId}:${proof.target.targetOS}',
        );
      }
      if (!runtimePlatforms.add(proof.target.targetOS)) {
        throw StateError(
          'Duplicate runtime proof platform for ${row.executionId}: '
          '${proof.target.targetOS}',
        );
      }
      if (!expectedRuntimePlatforms.contains(proof.target.targetOS)) {
        throw StateError(
          'Unknown runtime proof platform for ${row.executionId}: '
          '${proof.target.targetOS}',
        );
      }
      aggregateRuntimePlatforms.add(proof.target.targetOS);
      final key = _proofTargetKey(proof.target);
      final prepared = preparedByTarget[key];
      if (prepared == null) {
        throw StateError(
          'Runtime proof does not match a prepared target for '
          '${row.executionId}: $key',
        );
      }
      if (proof.nativeAssetId != prepared.nativeAssetId ||
          proof.identitySha256 != prepared.identitySha256) {
        throw StateError(
          'Runtime payload identity mismatch for $key: '
          'prepared_asset=${prepared.nativeAssetId} '
          'runtime_asset=${proof.nativeAssetId} '
          'prepared_identity_digest=${prepared.identitySha256} '
          'runtime_identity_digest=${proof.identitySha256}',
        );
      }
    }
    if (runtimePlatforms.length != expectedRuntimePlatforms.length ||
        !runtimePlatforms.containsAll(expectedRuntimePlatforms)) {
      throw StateError(
        'Runtime platform coverage mismatch for ${row.executionId}: '
        'expected=$expectedRuntimePlatforms actual=$runtimePlatforms',
      );
    }
  }

  final canonicalPreparedTargets = nexaHttpSupportedNativeTargets
      .map(_canonicalTargetKey)
      .toSet();
  if (aggregatePreparedTargets.length != canonicalPreparedTargets.length ||
      !aggregatePreparedTargets.containsAll(canonicalPreparedTargets)) {
    throw StateError(
      'Aggregate prepared target coverage mismatch: '
      'expected=$canonicalPreparedTargets actual=$aggregatePreparedTargets',
    );
  }
  const canonicalRuntimePlatforms = <String>{
    'android',
    'ios',
    'macos',
    'windows',
  };
  if (aggregateRuntimePlatforms.length != canonicalRuntimePlatforms.length ||
      !aggregateRuntimePlatforms.containsAll(canonicalRuntimePlatforms)) {
    throw StateError(
      'Aggregate runtime platform coverage mismatch: '
      'expected=$canonicalRuntimePlatforms actual=$aggregateRuntimePlatforms',
    );
  }
}

String _canonicalTargetKey(NexaHttpNativeTarget target) => <String>[
  target.targetOS,
  target.targetArchitecture,
  target.targetSdk ?? '',
  target.rustTargetTriple,
].join(':');

String _proofTargetKey(VerificationNativeTargetTuple target) => <String>[
  target.targetOS,
  target.targetArchitecture,
  target.targetSdk ?? '',
  target.rustTarget,
].join(':');
