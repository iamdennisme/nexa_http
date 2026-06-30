import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('workspace package with build script uses source build', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_workspace_source_',
    );
    addTearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    await Directory(p.join(workspace.path, '.git')).create();
    await File(
      p.join(workspace.path, 'scripts', 'build_native_macos.sh'),
    ).create(recursive: true);
    final packageRoot = Directory(
      p.join(workspace.path, 'packages', 'nexa_http_native_macos'),
    )..createSync(recursive: true);

    expect(
      shouldBuildNexaHttpNativeFromWorkspaceSource(
        packageRoot: packageRoot.path,
        buildScriptName: 'build_native_macos.sh',
      ),
      isTrue,
    );
  });

  test(
    'pub-cache package never falls back to workspace source build',
    () async {
      final pubCache = await Directory.systemTemp.createTemp(
        'nexa_http_pub_cache_',
      );
      addTearDown(() async {
        if (pubCache.existsSync()) {
          await pubCache.delete(recursive: true);
        }
      });

      final workspace = Directory(p.join(pubCache.path, 'git', 'repo-hash'))
        ..createSync(recursive: true);
      await Directory(p.join(workspace.path, '.git')).create();
      await File(
        p.join(workspace.path, 'scripts', 'build_native_macos.sh'),
      ).create(recursive: true);
      final packageRoot = Directory(
        p.join(workspace.path, 'packages', 'nexa_http_native_macos'),
      )..createSync(recursive: true);

      expect(
        shouldBuildNexaHttpNativeFromWorkspaceSource(
          packageRoot: packageRoot.path,
          buildScriptName: 'build_native_macos.sh',
          pubCacheRoot: pubCache.path,
        ),
        isFalse,
      );
    },
  );
}
