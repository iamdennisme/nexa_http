import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('runtime resolver exposes only host-platform primitives', () {
    final resolverFile = File(
      p.join(
        Directory.current.path,
        'lib',
        'src',
        'loader',
        'nexa_http_native_library_resolver.dart',
      ),
    );
    final contents = resolverFile.readAsStringSync();

    expect(contents, contains("export 'nexa_http_host_platform.dart';"));
    expect(contents, isNot(contains('nexa_http_dynamic_library_candidates')));
    expect(contents, isNot(contains('nexa_http_dynamic_library_override')));
  });
}
