import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('resolves GitHub release metadata through pub cache git remotes',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_release_consumer_git_cache_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final cacheRepo =
        Directory(p.join(tempDir.path, 'git', 'cache', 'nexa_http-cache'))
          ..createSync(recursive: true);
    await _runGit(cacheRepo.path, <String>['init', '--bare']);
    await _runGit(cacheRepo.path, <String>[
      'config',
      'remote.origin.url',
      'https://github.com/example/nexa_http.git',
    ]);

    final checkoutRepo =
        Directory(p.join(tempDir.path, 'git', 'nexa_http-checkout'))
          ..createSync(recursive: true);
    await _runGit(checkoutRepo.path, <String>['init']);
    await _runGit(
        checkoutRepo.path, <String>['config', 'user.name', 'Test User']);
    await _runGit(
      checkoutRepo.path,
      <String>['config', 'user.email', 'test@example.com'],
    );
    await _runGit(
      checkoutRepo.path,
      <String>['remote', 'add', 'origin', cacheRepo.path],
    );

    final markerFile = File(p.join(checkoutRepo.path, 'README.md'))
      ..writeAsStringSync('fixture');
    await _runGit(checkoutRepo.path, <String>['add', markerFile.path]);
    await _runGit(checkoutRepo.path, <String>['commit', '-m', 'fixture']);
    await _runGit(checkoutRepo.path, <String>['tag', 'v1.2.3']);

    final packageRoot = Directory(
      p.join(checkoutRepo.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);

    final releaseRef =
        await discoverNexaHttpNativeGitReleaseRef(packageRoot.path);

    expect(releaseRef.repositorySlug, 'example/nexa_http');
    expect(releaseRef.tag, 'v1.2.3');
  });

  test('retries transient HTTP failures while fetching release assets',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });

    var requestCount = 0;
    server.listen((request) async {
      requestCount += 1;
      if (requestCount == 1) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }

      request.response.add(utf8.encode('ok'));
      await request.response.close();
    });

    final bytes = await fetchNexaHttpNativeBytes(
      Uri.parse('http://127.0.0.1:${server.port}/asset'),
    );

    expect(utf8.decode(bytes), 'ok');
    expect(requestCount, 2);
  });
}

Future<void> _runGit(String workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    fail(
      'git ${arguments.join(' ')} failed in $workingDirectory\n'
      '${result.stdout}${result.stderr}',
    );
  }
}
