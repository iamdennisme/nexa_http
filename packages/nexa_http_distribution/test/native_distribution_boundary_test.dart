import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('carrier build hooks import the dedicated native distribution package',
      () async {
    final packageRoot = Directory.current.parent.path;
    final hookFiles = <String>[
      p.join(packageRoot, 'nexa_http_native_android', 'hook', 'build.dart'),
      p.join(packageRoot, 'nexa_http_native_ios', 'hook', 'build.dart'),
      p.join(packageRoot, 'nexa_http_native_macos', 'hook', 'build.dart'),
      p.join(packageRoot, 'nexa_http_native_windows', 'hook', 'build.dart'),
    ];

    for (final filePath in hookFiles) {
      final contents = await File(filePath).readAsString();
      expect(
        contents,
        contains("package:nexa_http_distribution/nexa_http_distribution.dart"),
      );
      expect(
        contents,
        isNot(contains("package:nexa_http/nexa_http_native_distribution.dart")),
      );
    }
  });
}
