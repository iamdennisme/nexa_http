import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/verification/consumer_fixture.dart';
import '../../scripts/verification/model.dart';

void main() {
  test('materializes one consumer workspace per suite execution', () async {
    var materializationRuns = 0;
    final outputDirectory = Directory('/tmp/consumer-android');
    final materializer = ConsumerFixtureMaterializer(
      workspaceRoot: '/workspace',
      outputDirectoryForExecution: (_) => outputDirectory,
      materialize:
          ({
            required workspaceRoot,
            required outputDirectory,
            required requestedPackages,
          }) async {
            materializationRuns += 1;
          },
    );
    final context = VerificationRunContext(
      const VerificationExecutionId('android-linux'),
    );

    final first = await materializer.prepare(context);
    final second = await materializer.prepare(context);

    expect(materializationRuns, 1);
    expect(identical(first, second), isTrue);
    expect(first.path, outputDirectory.path);
  });
}
