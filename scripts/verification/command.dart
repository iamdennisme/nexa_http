import 'dart:collection';
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

final class VerificationCommandFailure extends ProcessException {
  VerificationCommandFailure({
    required String executable,
    required List<String> arguments,
    required String message,
    required int errorCode,
    required Iterable<String> stdoutTail,
    required Iterable<String> stderrTail,
  }) : stdoutTail = List<String>.unmodifiable(stdoutTail),
       stderrTail = List<String>.unmodifiable(stderrTail),
       super(
         executable,
         List<String>.unmodifiable(arguments),
         message,
         errorCode,
       );

  final List<String> stdoutTail;
  final List<String> stderrTail;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (stdoutTail.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('  stdout tail:')
        ..write(stdoutTail.join('\n'));
    }
    if (stderrTail.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('  stderr tail:')
        ..write(stderrTail.join('\n'));
    }
    return buffer.toString();
  }
}

Future<void> runVerificationCommand(
  VerificationCommand command, {
  VerificationProcessRunner processRunner = const VerificationProcessRunner(),
  VerificationProcessLineHandler? onStdoutLine,
  VerificationProcessLineHandler? onStderrLine,
}) async {
  final stdoutTail = _BoundedLineTail(100);
  final stderrTail = _BoundedLineTail(100);
  final result = await processRunner.run(
    command.executable,
    command.arguments,
    workingDirectory: command.workingDirectory,
    environment: command.environment.isEmpty
        ? null
        : <String, String>{...Platform.environment, ...command.environment},
    onStdoutLine: (line) {
      stdoutTail.add(line);
      onStdoutLine?.call(line);
    },
    onStderrLine: (line) {
      stderrTail.add(line);
      onStderrLine?.call(line);
    },
  );
  if (result.exitCode != 0) {
    throw VerificationCommandFailure(
      executable: command.executable,
      arguments: command.arguments,
      message: 'Verification command failed in ${command.workingDirectory}',
      errorCode: result.exitCode,
      stdoutTail: stdoutTail.lines,
      stderrTail: stderrTail.lines,
    );
  }
}

final class _BoundedLineTail {
  _BoundedLineTail(this.limit);

  final int limit;
  final ListQueue<String> _lines = ListQueue<String>();

  Iterable<String> get lines => _lines;

  void add(String line) {
    if (_lines.length == limit) {
      _lines.removeFirst();
    }
    _lines.addLast(line);
  }
}
