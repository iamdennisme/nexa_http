import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('shared runtime loader no longer references generic candidate probing',
      () {
    final loaderFile = File(
      p.join(
        Directory.current.path,
        'lib',
        'src',
        'loader',
        'nexa_http_native_library_loader.dart',
      ),
    );
    final contents = loaderFile.readAsStringSync();

    expect(contents, isNot(contains('resolveNexaHttpDynamicLibraryCandidates')));
    expect(contents, isNot(contains('resolveNexaHttpDynamicLibraryOverridePath')));
    expect(contents, contains('registeredRuntime'));
    expect(contents, contains('explicitPath'));
  });
}
