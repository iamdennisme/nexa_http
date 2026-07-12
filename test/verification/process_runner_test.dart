import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/verification/process_runner.dart';

void main() {
  test('Windows resolves flutter.bat from FLUTTER_ROOT', () {
    final expected = p.join(r'D:\Flutter', 'bin', 'flutter.bat');

    expect(
      resolveVerificationProcessExecutable(
        'flutter',
        isWindows: true,
        environment: const <String, String>{'FLUTTER_ROOT': r'D:\Flutter'},
        fileExists: (path) => path == expected,
      ),
      expected,
    );
  });

  test('Windows falls back to the PATH-resolvable flutter.bat name', () {
    expect(
      resolveVerificationProcessExecutable(
        'flutter',
        isWindows: true,
        environment: const <String, String>{},
        fileExists: (_) => false,
      ),
      'flutter.bat',
    );
  });

  test('non-Windows executable names remain unchanged', () {
    expect(
      resolveVerificationProcessExecutable('flutter', isWindows: false),
      'flutter',
    );
  });

  test('streams stdout before the process exits', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_process_runner_',
    );
    addTearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final childScript = File('${tempDirectory.path}/child.dart');
    await childScript.writeAsString('''
import 'dart:async';

Future<void> main() async {
  print('first');
  await Future<void>.delayed(const Duration(milliseconds: 250));
  print('second');
}
''');

    final firstLine = Completer<void>();
    var runCompleted = false;
    final stdoutLines = <String>[];
    final runFuture = const VerificationProcessRunner()
        .run(
          Platform.resolvedExecutable,
          <String>[childScript.path],
          onStdoutLine: (line) {
            stdoutLines.add(line);
            if (line == 'first' && !firstLine.isCompleted) {
              firstLine.complete();
            }
          },
        )
        .whenComplete(() => runCompleted = true);

    await firstLine.future.timeout(const Duration(seconds: 5));
    expect(runCompleted, isFalse);

    final result = await runFuture;
    expect(result.exitCode, 0);
    expect(stdoutLines, <String>['first', 'second']);
  });
}
