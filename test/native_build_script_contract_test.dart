import 'dart:io';

import 'package:test/test.dart';

void main() {
  for (final script in <String>[
    'build_native_android.sh',
    'build_native_ios.sh',
    'build_native_macos.sh',
    'build_native_windows.sh',
  ]) {
    test('$script requires an explicit output directory', () async {
      final result = await Process.run('bash', <String>[
        'scripts/$script',
        'debug',
        '--target',
        _knownTarget(script),
      ]);

      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('Missing --output-dir'));
    });

    test('$script requires at least one explicit target', () async {
      final result = await Process.run('bash', <String>[
        'scripts/$script',
        'debug',
        '--output-dir',
        Directory.systemTemp.path,
      ]);

      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('Missing --target'));
    });

    test('$script rejects an unknown target before toolchain lookup', () async {
      final result = await Process.run(
        'bash',
        <String>[
          'scripts/$script',
          'debug',
          '--output-dir',
          Directory.systemTemp.path,
          '--target',
          'unknown-target',
        ],
        environment: const <String, String>{'PATH': '/usr/bin:/bin'},
      );

      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('Unsupported target'));
      expect('${result.stderr}', isNot(contains('Missing command')));
    });
  }
}

String _knownTarget(String script) => switch (script) {
  'build_native_android.sh' => 'aarch64-linux-android',
  'build_native_ios.sh' => 'aarch64-apple-ios',
  'build_native_macos.sh' => 'aarch64-apple-darwin',
  'build_native_windows.sh' => 'x86_64-pc-windows-msvc',
  _ => throw StateError('Unknown script $script'),
};
