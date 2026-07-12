import '../model.dart';
import '../released_consumer_adapter.dart';
import '../target_matrix.dart';

VerificationCheckDefinition releasedConsumerCheck({
  required List<IntegrationExecutionRow> executionRows,
  required ReleasedConsumerRunner runCheck,
}) {
  return VerificationCheckDefinition(
    id: const VerificationCheckId('released-consumer'),
    supportedExecutions: executionRows
        .map((row) => row.executionId)
        .toList(growable: false),
    action: (context) => runCheck(context.executionId),
  );
}
