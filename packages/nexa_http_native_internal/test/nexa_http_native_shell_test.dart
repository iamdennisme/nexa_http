import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('non-Windows hosts use bash from PATH', () async {
    expect(await resolveNexaHttpNativeBashExecutable(isWindows: false), 'bash');
  });

  test('Windows resolves Git Bash from ProgramFiles', () async {
    final expected = p.join(r'C:\Program Files', 'Git', 'bin', 'bash.exe');

    final executable = await resolveNexaHttpNativeBashExecutable(
      isWindows: true,
      environment: const <String, String>{'ProgramFiles': r'C:\Program Files'},
      fileExists: (path) => path == expected,
      runProcess: (_, _) async => ProcessResult(1, 1, '', ''),
    );

    expect(executable, expected);
  });

  test('Windows derives Git Bash from where git.exe', () async {
    final expected = p.join(r'D:\Tools\Git', 'bin', 'bash.exe');

    final executable = await resolveNexaHttpNativeBashExecutable(
      isWindows: true,
      environment: const <String, String>{},
      fileExists: (path) => path == expected,
      runProcess: (executable, arguments) async {
        expect(executable, 'where.exe');
        expect(arguments, const <String>['git.exe']);
        return ProcessResult(
          1,
          0,
          '${p.join(r'D:\Tools\Git', 'cmd', 'git.exe')}\r\n',
          '',
        );
      },
    );

    expect(executable, expected);
  });

  test('Windows fails with issue-ready toolchain context', () async {
    await expectLater(
      resolveNexaHttpNativeBashExecutable(
        isWindows: true,
        environment: const <String, String>{},
        fileExists: (_) => false,
        runProcess: (_, _) async => ProcessResult(1, 1, '', ''),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('stage=native build toolchain resolution'),
            contains('platform=windows'),
            contains('expected_action='),
            contains('underlying_error='),
          ),
        ),
      ),
    );
  });
}
