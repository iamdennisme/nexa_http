import 'package:test/test.dart';

import '../../scripts/verification/command.dart';
import '../../scripts/verification/development_path_adapter.dart';
import '../../scripts/verification/model.dart';

void main() {
  test('Apple development path runs both macOS and iOS builds', () async {
    final commands = <VerificationCommand>[];
    final runner = createDevelopmentPathRunner(
      '/workspace',
      (command) async => commands.add(command),
    );

    await runner(const VerificationExecutionId('apple-macos'));

    expect(commands.map((command) => command.arguments), <List<String>>[
      <String>['clean'],
      <String>['pub', 'get'],
      <String>['test'],
      <String>['build', 'macos', '--debug'],
      <String>['build', 'ios', '--simulator', '--debug', '--no-codesign'],
    ]);
  });
}
