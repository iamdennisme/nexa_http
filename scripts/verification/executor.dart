import 'model.dart';
import 'planner.dart';
import 'report.dart';

final class VerificationExecutionResult {
  VerificationExecutionResult(
    List<VerificationCheckId> completedCheckIds,
    List<VerifiedNativeArtifactIdentity> preparedArtifactIdentities,
    List<VerificationRuntimePayloadProof> runtimePayloadProofs,
  ) : completedCheckIds = List<VerificationCheckId>.unmodifiable(
        completedCheckIds,
      ),
      preparedArtifactIdentities =
          List<VerifiedNativeArtifactIdentity>.unmodifiable(
            preparedArtifactIdentities,
          ),
      runtimePayloadProofs = List<VerificationRuntimePayloadProof>.unmodifiable(
        runtimePayloadProofs,
      );

  final List<VerificationCheckId> completedCheckIds;
  final List<VerifiedNativeArtifactIdentity> preparedArtifactIdentities;
  final List<VerificationRuntimePayloadProof> runtimePayloadProofs;
}

final class VerificationExecutor {
  const VerificationExecutor();

  Future<VerificationExecutionResult> execute(
    VerificationExecutionPlan plan,
  ) async {
    if (plan.nodes.isEmpty) {
      throw StateError('Cannot execute an empty verification plan');
    }
    final context = VerificationRunContext(plan.nodes.first.executionId);
    final completedCheckIds = <VerificationCheckId>[];
    for (final node in plan.nodes) {
      final action = node.check.action;
      if (action == null) {
        throw StateError('Check ${node.check.id} has no execution action');
      }
      await action(context);
      completedCheckIds.add(node.check.id);
    }
    return VerificationExecutionResult(
      completedCheckIds,
      await context.preparedArtifactIdentitiesOrEmpty(),
      await context
          .runtimePayloadProofsOrEmpty<VerificationRuntimePayloadProof>(),
    );
  }
}
