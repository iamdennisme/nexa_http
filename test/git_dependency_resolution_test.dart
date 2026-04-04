import 'dart:io';

import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'tagged checkout resolves release identity and manifest uri from the selected tag',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'nexa_http_release_identity_test_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final repoDir = Directory(p.join(tempRoot.path, 'repo'));
      await repoDir.create(recursive: true);
      final packageDir = Directory(
        p.join(repoDir.path, 'packages', 'nexa_http_native_macos'),
      );
      await packageDir.create(recursive: true);
      await _writeFile(
        repoDir,
        'packages/nexa_http_native_macos/pubspec.yaml',
        'name: nexa_http_native_macos\nversion: 1.0.1\nenvironment:\n  sdk: ^3.11.0\n',
      );

      await Process.run('git', [
        'init',
        '-b',
        'main',
      ], workingDirectory: repoDir.path);
      await Process.run('git', [
        'config',
        'user.email',
        'test@example.com',
      ], workingDirectory: repoDir.path);
      await Process.run('git', [
        'config',
        'user.name',
        'Test User',
      ], workingDirectory: repoDir.path);
      await Process.run('git', ['add', '.'], workingDirectory: repoDir.path);
      await Process.run('git', [
        'commit',
        '-m',
        'test fixture',
      ], workingDirectory: repoDir.path);
      await Process.run('git', [
        'tag',
        'v0.0.1',
      ], workingDirectory: repoDir.path);

      final releaseIdentity = resolveNexaHttpNativeReleaseIdentity(
        packageRoot: packageDir.uri,
        environment: const <String, String>{},
      );
      final manifestUri = resolveNexaHttpNativeManifestUri(
        releaseIdentity: releaseIdentity,
        environment: const <String, String>{},
      );

      expect(releaseIdentity, 'v0.0.1');
      expect(
        manifestUri.toString(),
        'https://github.com/iamdennisme/nexa_http/releases/download/v0.0.1/'
        'nexa_http_native_assets_manifest.json',
      );
    },
  );
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
