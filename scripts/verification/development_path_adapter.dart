import 'package:path/path.dart' as p;

import 'command.dart';
import 'model.dart';

typedef DevelopmentPathRunner =
    Future<void> Function(VerificationExecutionId executionId);

DevelopmentPathRunner createDevelopmentPathRunner(
  String workspaceRoot,
  VerificationCommandRunner runCommand,
) {
  final demoDirectory = p.join(workspaceRoot, 'app', 'demo');
  return (executionId) async {
    final environment = <String, String>{
      'NEXA_HTTP_NATIVE_PREPARED_DIR': p.join(
        workspaceRoot,
        '.dart_tool',
        'nexa_http_native',
        'integration',
        executionId.value,
      ),
    };
    final commands = <List<String>>[
      const <String>['clean'],
      const <String>['pub', 'get'],
      const <String>['test'],
      ..._buildCommandsForExecution(executionId),
    ];
    for (final arguments in commands) {
      await runCommand(
        VerificationCommand(
          executable: 'flutter',
          arguments: arguments,
          workingDirectory: demoDirectory,
          environment: environment,
        ),
      );
    }
  };
}

List<List<String>> _buildCommandsForExecution(
  VerificationExecutionId executionId,
) {
  return switch (executionId.value) {
    'android-linux' => <List<String>>[
      const <String>['build', 'apk', '--debug'],
    ],
    'apple-macos' => <List<String>>[
      const <String>['build', 'macos', '--debug'],
      const <String>['build', 'ios', '--simulator', '--debug', '--no-codesign'],
    ],
    'windows-x64' => <List<String>>[
      const <String>['build', 'windows', '--debug'],
    ],
    _ => throw StateError(
      'No development path mapping for execution $executionId',
    ),
  };
}
