import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('runtime loader keeps per-platform candidate strategy modules', () {
    final files = <String>[
      p.join('lib', 'src', 'loader',
          'nexa_http_android_dynamic_library_candidates.dart'),
      p.join('lib', 'src', 'loader',
          'nexa_http_ios_dynamic_library_candidates.dart'),
      p.join('lib', 'src', 'loader',
          'nexa_http_macos_dynamic_library_candidates.dart'),
      p.join('lib', 'src', 'loader',
          'nexa_http_windows_dynamic_library_candidates.dart'),
    ];

    for (final relativePath in files) {
      expect(
        File(relativePath).existsSync(),
        isTrue,
        reason: 'Expected runtime strategy module $relativePath to exist.',
      );
    }
  });
}
