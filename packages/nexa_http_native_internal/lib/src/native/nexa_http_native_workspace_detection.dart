import 'dart:io';

import 'package:path/path.dart' as p;

bool isNexaHttpNativeWorkspacePackage(
  String packageRoot, {
  Map<String, String>? environment,
}) {
  final normalizedPackageRoot = _normalizePath(packageRoot);
  final pubCacheRoots = _pubCacheRoots(environment ?? Platform.environment);
  final isPubCachePackage = pubCacheRoots.any(
    (pubCacheRoot) =>
        p.equals(pubCacheRoot, normalizedPackageRoot) ||
        p.isWithin(pubCacheRoot, normalizedPackageRoot),
  );
  if (isPubCachePackage) {
    return false;
  }

  final workspaceRoot = p.normalize(p.join(normalizedPackageRoot, '..', '..'));
  final gitMetadataPath = p.join(workspaceRoot, '.git');
  return Directory(gitMetadataPath).existsSync() ||
      File(gitMetadataPath).existsSync();
}

List<String> _pubCacheRoots(Map<String, String> environment) {
  final roots = <String>{};

  void addRoot(String? value) {
    if (value == null || value.isEmpty) {
      return;
    }
    roots.add(_normalizePath(value));
  }

  addRoot(environment['PUB_CACHE']);
  addRoot(_joinPath(environment['HOME'], '.pub-cache'));
  addRoot(_joinPath(environment['USERPROFILE'], '.pub-cache'));
  addRoot(_joinPath(environment['LOCALAPPDATA'], 'Pub', 'Cache'));

  return roots.toList(growable: false);
}

String? _joinPath(String? root, String segmentA, [String? segmentB]) {
  if (root == null || root.isEmpty) {
    return null;
  }
  return segmentB == null
      ? p.join(root, segmentA)
      : p.join(root, segmentA, segmentB);
}

String _normalizePath(String value) {
  try {
    return p.normalize(Directory(value).resolveSymbolicLinksSync());
  } on FileSystemException {
    return p.normalize(value);
  }
}
