import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('workspace tools is a thin CLI entrypoint', () {
    final source = File('scripts/workspace_tools.dart').readAsStringSync();

    expect(source, contains("import 'verification/cli.dart';"));
    expect(source, isNot(contains('Process.run')));
    expect(source, isNot(contains('VerificationCheckId(')));
    expect(source, isNot(contains('flutter create')));
    expect(source, isNot(contains('build_native_')));
    expect(source.split('\n'), hasLength(lessThan(40)));
  });
}
