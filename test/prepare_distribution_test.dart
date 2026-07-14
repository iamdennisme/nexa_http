import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/prepare_distribution.dart';

void main() {
  test('materializes packages without prebuilding carrier binaries', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_prepare_distribution_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    var materialized = false;

    await prepareDistributionWorkspace(
      workspaceRoot: tempDir.path,
      outputDirectory: p.join(tempDir.path, '.dist', 'workspace'),
      requestedPackages: {'nexa_http', 'nexa_http_native_android'},
      materializeWorkspace:
          ({
            required String workspaceRoot,
            required String outputDirectory,
            Set<String>? requestedPackages,
          }) async {
            materialized = true;
            expect(requestedPackages, {
              'nexa_http',
              'nexa_http_native_android',
            });
          },
    );

    expect(materialized, isTrue);
  });
}
