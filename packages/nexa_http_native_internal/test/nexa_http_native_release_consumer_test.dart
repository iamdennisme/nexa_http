import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'release ref resolves the GitHub origin through the pub cache',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'nexa_http_pub_cache_release_ref_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));

      final cacheRepository = Directory(
        p.join(tempDirectory.path, 'git', 'cache', 'nexa_http-cache'),
      )..createSync(recursive: true);
      await _runGit(cacheRepository, const <String>['init', '--bare']);
      await _runGit(cacheRepository, const <String>[
        'remote',
        'add',
        'origin',
        'https://github.com/example/nexa_http.git',
      ]);

      final checkout = Directory(
        p.join(tempDirectory.path, 'git', 'nexa_http-release-checkout'),
      )..createSync(recursive: true);
      await _runGit(checkout, const <String>['init']);
      await _runGit(checkout, const <String>[
        'config',
        'user.email',
        'test@example.com',
      ]);
      await _runGit(checkout, const <String>[
        'config',
        'user.name',
        'nexa_http test',
      ]);
      final packageRoot = Directory(
        p.join(checkout.path, 'packages', 'nexa_http_native_macos'),
      )..createSync(recursive: true);
      await File(
        p.join(packageRoot.path, 'pubspec.yaml'),
      ).writeAsString('name: nexa_http_native_macos\n');
      await _runGit(checkout, const <String>['add', '.']);
      await _runGit(checkout, const <String>['commit', '-m', 'fixture']);
      await _runGit(checkout, const <String>['tag', 'v2.0.0']);
      await _runGit(checkout, <String>[
        'remote',
        'add',
        'origin',
        cacheRepository.path,
      ]);

      final releaseRef = await discoverNexaHttpNativeGitReleaseRef(
        packageRoot.path,
      );

      expect(releaseRef.repositorySlug, 'example/nexa_http');
      expect(releaseRef.tag, 'v2.0.0');
    },
  );
}

Future<void> _runGit(Directory workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory.path,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${arguments.join(' ')} failed in ${workingDirectory.path}: '
      '${result.stdout}${result.stderr}',
    );
  }
}
