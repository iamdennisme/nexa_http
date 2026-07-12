import 'dart:convert';
import 'dart:io';

typedef VerificationProcessLineHandler = void Function(String line);

final class VerificationProcessResult {
  const VerificationProcessResult({
    required this.exitCode,
    required this.elapsed,
  });

  final int exitCode;
  final Duration elapsed;
}

final class VerificationProcessRunner {
  const VerificationProcessRunner();

  Future<VerificationProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    VerificationProcessLineHandler? onStdoutLine,
    VerificationProcessLineHandler? onStderrLine,
  }) async {
    final stopwatch = Stopwatch()..start();
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onStdoutLine?.call(line));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onStderrLine?.call(line));

    final exitCode = await process.exitCode;
    await Future.wait<void>(<Future<void>>[stdoutDone, stderrDone]);
    stopwatch.stop();
    return VerificationProcessResult(
      exitCode: exitCode,
      elapsed: stopwatch.elapsed,
    );
  }
}
