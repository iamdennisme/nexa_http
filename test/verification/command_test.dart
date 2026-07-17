import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/verification/command.dart';

void main() {
  test(
    'failed command retains bounded output while forwarding live lines',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'nexa_http_command_failure_',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final childScript = File('${tempDirectory.path}/child.dart');
      await childScript.writeAsString('''
import 'dart:io';

void main() {
  for (var index = 0; index < 105; index += 1) {
    stdout.writeln('stdout-\$index');
  }
  for (var index = 0; index < 103; index += 1) {
    stderr.writeln('stderr-\$index');
  }
  stderr.writeln('PackageManagerInternal.freeStorage');
  stderr.writeln('null object reference');
  exitCode = 23;
}
''');
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      Object? caughtError;

      try {
        await runVerificationCommand(
          VerificationCommand(
            executable: Platform.resolvedExecutable,
            arguments: <String>[childScript.path],
            workingDirectory: tempDirectory.path,
          ),
          onStdoutLine: stdoutLines.add,
          onStderrLine: stderrLines.add,
        );
      } catch (error) {
        caughtError = error;
      }

      expect(caughtError, isA<ProcessException>());
      expect(caughtError, isA<VerificationCommandFailure>());
      final failure = caughtError! as VerificationCommandFailure;
      expect(failure.errorCode, 23);
      expect(failure.stdoutTail, hasLength(100));
      expect(failure.stdoutTail.first, 'stdout-5');
      expect(failure.stdoutTail.last, 'stdout-104');
      expect(failure.stderrTail, hasLength(100));
      expect(failure.stderrTail.first, 'stderr-5');
      expect(failure.stderrTail.sublist(98), <String>[
        'PackageManagerInternal.freeStorage',
        'null object reference',
      ]);
      expect(stdoutLines, hasLength(105));
      expect(stdoutLines.first, 'stdout-0');
      expect(stderrLines, hasLength(105));
      expect(stderrLines.first, 'stderr-0');
      expect(failure.toString(), contains('stdout-104'));
      expect(
        failure.toString(),
        contains('PackageManagerInternal.freeStorage'),
      );
      expect(failure.toString(), isNot(contains('stdout-0')));
      expect(() => failure.stdoutTail.add('mutated'), throwsUnsupportedError);
      expect(() => failure.stderrTail.add('mutated'), throwsUnsupportedError);
    },
  );
}
