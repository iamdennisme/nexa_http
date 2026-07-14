import 'dart:io';

import 'verification/cli.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await runVerificationCli(
      arguments,
      writeStdout: stdout.writeln,
      writeStderr: stderr.writeln,
    );
  } on VerificationCliUsageError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
