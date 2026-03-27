import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('git consumers can depend on nexa_http and the Android carrier together', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'nexa_http_git_resolution_test_',
    );
    addTearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final repoDir = Directory(p.join(tempRoot.path, 'repo'));
    await repoDir.create(recursive: true);

    await _writeFile(
      repoDir,
      'packages/nexa_http/pubspec.yaml',
      File('packages/nexa_http/pubspec.yaml').readAsStringSync(),
    );
    await _writeFile(
      repoDir,
      'packages/nexa_http/lib/nexa_http.dart',
      'library nexa_http;\n',
    );

    final normalizedCarrierPubspec = File(
      'packages/nexa_http_native_android/pubspec.yaml',
    ).readAsStringSync().replaceAll(
      'https://github.com/iamdennisme/rust_net.git',
      'file://${repoDir.path}',
    );
    await _writeFile(
      repoDir,
      'packages/nexa_http_native_android/pubspec.yaml',
      normalizedCarrierPubspec,
    );
    final androidOverrides = File(
      'packages/nexa_http_native_android/pubspec_overrides.yaml',
    );
    if (androidOverrides.existsSync()) {
      await _writeFile(
        repoDir,
        'packages/nexa_http_native_android/pubspec_overrides.yaml',
        androidOverrides.readAsStringSync(),
      );
    }
    await _writeFile(
      repoDir,
      'packages/nexa_http_native_android/lib/nexa_http_native_android.dart',
      'library nexa_http_native_android;\n',
    );

    await Process.run('git', ['init', '-b', 'main'], workingDirectory: repoDir.path);
    await Process.run(
      'git',
      ['config', 'user.email', 'test@example.com'],
      workingDirectory: repoDir.path,
    );
    await Process.run(
      'git',
      ['config', 'user.name', 'Test User'],
      workingDirectory: repoDir.path,
    );
    await Process.run('git', ['add', '.'], workingDirectory: repoDir.path);
    await Process.run(
      'git',
      ['commit', '-m', 'test fixture'],
      workingDirectory: repoDir.path,
    );
    await Process.run(
      'git',
      ['tag', 'v1.0.0'],
      workingDirectory: repoDir.path,
    );

    final consumerDir = Directory(p.join(tempRoot.path, 'consumer'));
    await consumerDir.create(recursive: true);
    await _writeFile(
      consumerDir,
      'pubspec.yaml',
      '''
name: temp_consumer
environment:
  sdk: ^3.11.0
dependencies:
  nexa_http:
    git:
      url: file://${repoDir.path}
      tag_pattern: 'v{{version}}'
      path: packages/nexa_http
    version: ^1.0.0
  nexa_http_native_android:
    git:
      url: file://${repoDir.path}
      tag_pattern: 'v{{version}}'
      path: packages/nexa_http_native_android
    version: ^1.0.0
''',
    );

    final result = await Process.run(
      Platform.resolvedExecutable,
      const ['pub', 'get'],
      workingDirectory: consumerDir.path,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}${result.stderr}',
    );
  });
}

Future<void> _writeFile(
  Directory root,
  String relativePath,
  String contents,
) async {
  final file = File(p.join(root.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
