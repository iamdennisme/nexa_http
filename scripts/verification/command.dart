import 'dart:io';

import 'process_runner.dart';

final class VerificationCommand {
  const VerificationCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    this.environment = const <String, String>{},
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
}

typedef VerificationCommandRunner =
    Future<void> Function(VerificationCommand command);

Future<void> runVerificationCommand(
  VerificationCommand command, {
  VerificationProcessRunner processRunner = const VerificationProcessRunner(),
  VerificationProcessLineHandler? onStdoutLine,
  VerificationProcessLineHandler? onStderrLine,
}) async {
  final result = await processRunner.run(
    command.executable,
    command.arguments,
    workingDirectory: command.workingDirectory,
    environment: command.environment.isEmpty
        ? null
        : <String, String>{...Platform.environment, ...command.environment},
    onStdoutLine: onStdoutLine,
    onStderrLine: onStderrLine,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      command.executable,
      command.arguments,
      'Verification command failed in ${command.workingDirectory}',
      result.exitCode,
    );
  }
}
