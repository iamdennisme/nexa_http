import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('treats local workspace packages as workspace packages', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_detection_workspace_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final workspaceRoot = Directory(p.join(tempDir.path, 'nexa_http'))
      ..createSync();
    Directory(p.join(workspaceRoot.path, '.git')).createSync();
    final packageRoot = Directory(
      p.join(workspaceRoot.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);

    expect(isNexaHttpNativeWorkspacePackage(packageRoot.path), isTrue);
  });

  test('treats pub cache git packages as release-consumer packages', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_detection_pub_cache_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final pubCacheRoot = Directory(p.join(tempDir.path, 'pub-cache'))
      ..createSync();
    final gitCheckoutRoot = Directory(
      p.join(pubCacheRoot.path, 'git', 'nexa_http-a4e51b9'),
    )..createSync(recursive: true);
    Directory(p.join(gitCheckoutRoot.path, '.git')).createSync();
    final packageRoot = Directory(
      p.join(gitCheckoutRoot.path, 'packages', 'nexa_http_native_windows'),
    )..createSync(recursive: true);

    expect(
      isNexaHttpNativeWorkspacePackage(
        packageRoot.path,
        environment: <String, String>{'PUB_CACHE': pubCacheRoot.path},
      ),
      isFalse,
    );
  });

  test('supports worktree-style git metadata files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_detection_worktree_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final workspaceRoot = Directory(p.join(tempDir.path, 'nexa_http'))
      ..createSync();
    File(p.join(workspaceRoot.path, '.git'))
        .writeAsStringSync('gitdir: /tmp/example');
    final packageRoot = Directory(
      p.join(workspaceRoot.path, 'packages', 'nexa_http_native_ios'),
    )..createSync(recursive: true);

    expect(isNexaHttpNativeWorkspacePackage(packageRoot.path), isTrue);
  });

  test('preserves .gitkeep while removing stale workspace artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_artifacts_cleanup_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final artifactsDir = Directory(p.join(tempDir.path, 'macos', 'Libraries'))
      ..createSync(recursive: true);
    final gitkeepFile = File(p.join(artifactsDir.path, '.gitkeep'))
      ..writeAsStringSync('');
    File(p.join(artifactsDir.path, 'stale.dylib')).writeAsStringSync('old');
    Directory(p.join(artifactsDir.path, 'nested')).createSync();
    File(
      p.join(artifactsDir.path, 'nested', 'stale.txt'),
    ).writeAsStringSync('nested');

    await prepareNexaHttpNativeWorkspaceArtifactsDirectory(artifactsDir.path);

    expect(artifactsDir.existsSync(), isTrue);
    expect(gitkeepFile.existsSync(), isTrue);
    expect(
        File(p.join(artifactsDir.path, 'stale.dylib')).existsSync(), isFalse);
    expect(
        Directory(p.join(artifactsDir.path, 'nested')).existsSync(), isFalse);
  });

  test('creates missing workspace artifacts directory with .gitkeep', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_artifacts_create_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final artifactsDir =
        Directory(p.join(tempDir.path, 'windows', 'Libraries'));

    await prepareNexaHttpNativeWorkspaceArtifactsDirectory(artifactsDir.path);

    expect(artifactsDir.existsSync(), isTrue);
    expect(File(p.join(artifactsDir.path, '.gitkeep')).existsSync(), isTrue);
  });
}
