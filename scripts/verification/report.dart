import 'model.dart';

enum VerificationCoverageStatus { passed, failed }

final class VerificationCoverageReport {
  VerificationCoverageReport({
    required this.suiteId,
    required this.executionId,
    required List<VerificationCheckId> plannedCheckIds,
    required List<VerificationCheckId> completedCheckIds,
    required this.status,
  }) : plannedCheckIds = List<VerificationCheckId>.unmodifiable(
         plannedCheckIds,
       ),
       completedCheckIds = List<VerificationCheckId>.unmodifiable(
         completedCheckIds,
       );

  factory VerificationCoverageReport.fromJson(Map<String, Object?> json) {
    if (json['schema_version'] != 1 ||
        json['suite_id'] is! String ||
        json['execution_id'] is! String ||
        json['planned_check_ids'] is! List<Object?> ||
        json['completed_check_ids'] is! List<Object?> ||
        json['status'] is! String) {
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
    );
  }

  final VerificationSuiteId suiteId;
  final VerificationExecutionId executionId;
  final List<VerificationCheckId> plannedCheckIds;
  final List<VerificationCheckId> completedCheckIds;
  final VerificationCoverageStatus status;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': 1,
    'suite_id': suiteId.value,
    'execution_id': executionId.value,
    'planned_check_ids': plannedCheckIds
        .map((checkId) => checkId.value)
        .toList(growable: false),
    'completed_check_ids': completedCheckIds
        .map((checkId) => checkId.value)
        .toList(growable: false),
    'status': status.name,
  };
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
}
