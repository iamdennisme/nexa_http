import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('workspace exposes only the nexa_http package family', () {
    final packagesDir = Directory(p.join(Directory.current.path, 'packages'));
    final packageNames = packagesDir
        .listSync()
        .whereType<Directory>()
        .map((dir) => File(p.join(dir.path, 'pubspec.yaml')))
        .where((file) => file.existsSync())
        .map((file) => (loadYaml(file.readAsStringSync()) as YamlMap)['name'])
        .whereType<String>()
        .toSet();

    expect(packageNames, contains('nexa_http'));
    expect(packageNames, contains('nexa_http_native_internal'));
    expect(packageNames, contains('nexa_http_native_android'));
    expect(packageNames, contains('nexa_http_native_ios'));
    expect(packageNames, contains('nexa_http_native_macos'));
    expect(packageNames, contains('nexa_http_native_windows'));
    expect(packageNames, isNot(contains('nexa_http_runtime')));
    expect(packageNames, isNot(contains('nexa_http_distribution')));
  });
}
