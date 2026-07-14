import 'dart:io';

import 'package:path/path.dart' as p;

bool shouldBuildNexaHttpNativeFromWorkspaceSource({
  required String packageRoot,
  required String buildScriptName,
  String? pubCacheRoot,
}) {
  final workspaceRoot = nexaHttpWorkspaceRootForPackage(packageRoot);
  if (!_hasGitRepository(workspaceRoot)) {
    return false;
  }
  if (_isInsidePubCache(packageRoot, pubCacheRoot: pubCacheRoot)) {
    return false;
  }
  return File(p.join(workspaceRoot, 'scripts', buildScriptName)).existsSync();
}

String nexaHttpWorkspaceRootForPackage(String packageRoot) {
  return p.normalize(p.join(packageRoot, '..', '..'));
}

bool _hasGitRepository(String workspaceRoot) {
  return Directory(p.join(workspaceRoot, '.git')).existsSync() ||
      File(p.join(workspaceRoot, '.git')).existsSync();
}

bool _isInsidePubCache(String packageRoot, {String? pubCacheRoot}) {
  final pubCache = pubCacheRoot == null
      ? _pubCacheRoot()
      : p.normalize(p.absolute(pubCacheRoot));
  if (pubCache == null) {
    return false;
  }
  final normalizedPackageRoot = p.normalize(p.absolute(packageRoot));
  return p.equals(normalizedPackageRoot, pubCache) ||
      p.isWithin(pubCache, normalizedPackageRoot);
}

String? _pubCacheRoot() {
  final configured = Platform.environment['PUB_CACHE'];
  if (configured != null && configured.trim().isNotEmpty) {
    return p.normalize(p.absolute(configured));
  }

  final home = Platform.environment['HOME'];
  if (home == null || home.trim().isEmpty) {
    return null;
  }
  return p.normalize(p.absolute(p.join(home, '.pub-cache')));
}
