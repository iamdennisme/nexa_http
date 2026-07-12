import 'dart:io';

import '../materialize_distribution.dart';
import 'model.dart';

typedef ConsumerWorkspaceMaterializer =
    Future<void> Function({
      required String workspaceRoot,
      required String outputDirectory,
      required Set<String> requestedPackages,
    });

typedef ConsumerOutputDirectoryResolver =
    Directory Function(VerificationExecutionId executionId);

final class ConsumerFixtureMaterializer {
  const ConsumerFixtureMaterializer({
    required this.workspaceRoot,
    required this.outputDirectoryForExecution,
    this.materialize = materializeDistributionWorkspace,
  });

  final String workspaceRoot;
  final ConsumerOutputDirectoryResolver outputDirectoryForExecution;
  final ConsumerWorkspaceMaterializer materialize;

  Future<Directory> prepare(VerificationRunContext context) {
    final resourceKey = VerificationResourceKey(
      'consumer-fixture:${context.executionId.value}',
    );
    return context.memoize(resourceKey, () async {
      final outputDirectory = outputDirectoryForExecution(context.executionId);
      await materialize(
        workspaceRoot: workspaceRoot,
        outputDirectory: outputDirectory.path,
        requestedPackages: _packagesForExecution(context.executionId),
      );
      return outputDirectory;
    });
  }
}

Set<String> _packagesForExecution(VerificationExecutionId executionId) {
  return switch (executionId.value) {
    'android-linux' ||
    'candidate-android' => <String>{'nexa_http', 'nexa_http_native_android'},
    'apple-macos' => <String>{
      'nexa_http',
      'nexa_http_native_ios',
      'nexa_http_native_macos',
    },
    'windows-x64' => <String>{'nexa_http', 'nexa_http_native_windows'},
    'candidate-ios' => <String>{'nexa_http', 'nexa_http_native_ios'},
    'candidate-macos' => <String>{'nexa_http', 'nexa_http_native_macos'},
    'candidate-windows' => <String>{'nexa_http', 'nexa_http_native_windows'},
    _ => throw StateError(
      'No consumer package projection for execution $executionId',
    ),
  };
}
