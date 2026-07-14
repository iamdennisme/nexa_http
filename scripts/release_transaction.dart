import 'dart:io';

import 'release/release_transaction_cli.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await runReleaseTransactionCli(arguments);
  } on ReleaseTransactionCliUsageError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
