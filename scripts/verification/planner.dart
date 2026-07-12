import 'catalog.dart';
import 'model.dart';

final class VerificationPlanNode {
  const VerificationPlanNode({required this.check, required this.executionId});

  final VerificationCheckDefinition check;
  final VerificationExecutionId executionId;

  VerificationExecutionKey get key =>
      VerificationExecutionKey(checkId: check.id, executionId: executionId);
}

final class VerificationExecutionPlan {
  const VerificationExecutionPlan(this.nodes);

  final List<VerificationPlanNode> nodes;
}

final class VerificationPlanner {
  const VerificationPlanner(this.catalog);

  final VerificationCatalog catalog;

  VerificationExecutionPlan planSuite(
    VerificationSuiteId suiteId,
    VerificationExecutionId executionId,
  ) {
    return _plan(catalog.checksForSuite(suiteId), executionId);
  }

  VerificationExecutionPlan planCheck(
    VerificationCheckId checkId,
    VerificationExecutionId executionId,
  ) {
    return _plan(<VerificationCheckDefinition>[
      catalog.checkById(checkId),
    ], executionId);
  }

  VerificationExecutionPlan _plan(
    Iterable<VerificationCheckDefinition> requestedChecks,
    VerificationExecutionId executionId,
  ) {
    final plannedCheckIds = <VerificationCheckId>{};
    final nodes = <VerificationPlanNode>[];

    void addCheck(VerificationCheckDefinition check) {
      if (!check.supportedExecutions.contains(executionId)) {
        throw StateError(
          'Check ${check.id} is not covered by execution $executionId',
        );
      }
      if (!plannedCheckIds.add(check.id)) {
        return;
      }
      for (final dependencyId in check.dependencies) {
        addCheck(catalog.checkById(dependencyId));
      }
      nodes.add(VerificationPlanNode(check: check, executionId: executionId));
    }

    for (final check in requestedChecks) {
      addCheck(check);
    }

    return VerificationExecutionPlan(
      List<VerificationPlanNode>.unmodifiable(nodes),
    );
  }
}
