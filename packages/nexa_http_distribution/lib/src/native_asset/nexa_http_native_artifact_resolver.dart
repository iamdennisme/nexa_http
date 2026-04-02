import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'nexa_http_native_digest.dart';
import 'nexa_http_native_file_transfer.dart';
import 'nexa_http_native_manifest.dart';

const _manifestPathEnvironmentVariable = 'NEXA_HTTP_NATIVE_MANIFEST_PATH';
const _releaseBaseUrlEnvironmentVariable = 'NEXA_HTTP_NATIVE_RELEASE_BASE_URL';
const _defaultReleaseBaseUrl =
    'https://github.com/iamdennisme/nexa_http/releases/download';
const _manifestFileName = 'nexa_http_native_assets_manifest.json';
const _artifactResolutionModeEnvironmentVariable =
    'NEXA_HTTP_NATIVE_ARTIFACT_MODE';

enum NexaHttpNativeArtifactResolutionMode {
  workspaceDev,
  releaseConsumer,
}

typedef SourceDirCandidatesBuilder = Iterable<String> Function(
  String sourceDir,
);
typedef SourceDirBuilder = Future<void> Function(String sourceDir);

Future<File> resolveNexaHttpNativeArtifactFile({
  required Uri packageRoot,
  required Uri cacheRoot,
  required NexaHttpNativeArtifactResolutionMode mode,
  required String packageVersion,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required String packagedRelativePath,
  required Map<String, String> environment,
  required String libPathEnvironmentVariable,
  required String sourceDirEnvironmentVariable,
  required SourceDirCandidatesBuilder sourceDirCandidates,
  String? defaultSourceDir,
  SourceDirBuilder? buildDefaultSourceDir,
}) async {
  final explicitFile = await _resolveExplicitFile(
    environment: environment,
    libPathEnvironmentVariable: libPathEnvironmentVariable,
  );
  if (explicitFile != null) {
    return explicitFile;
  }

  final sourceDirFile = await _resolveSourceDirOverride(
    environment: environment,
    sourceDirEnvironmentVariable: sourceDirEnvironmentVariable,
    sourceDirCandidates: sourceDirCandidates,
    libPathEnvironmentVariable: libPathEnvironmentVariable,
  );
  if (sourceDirFile != null) {
    return sourceDirFile;
  }

  if (mode == NexaHttpNativeArtifactResolutionMode.workspaceDev &&
      defaultSourceDir != null &&
      defaultSourceDir.isNotEmpty) {
    final builtFromDefault = await _resolveDefaultSourceDir(
      defaultSourceDir: defaultSourceDir,
      sourceDirCandidates: sourceDirCandidates,
      buildDefaultSourceDir: buildDefaultSourceDir,
    );
    if (builtFromDefault != null) {
      return builtFromDefault;
    }
  }

  final packagedFile = File.fromUri(packageRoot.resolve(packagedRelativePath));
  if (await packagedFile.exists()) {
    return packagedFile;
  }

  return _downloadFromManifest(
    cacheRoot: cacheRoot,
    packageVersion: packageVersion,
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    environment: environment,
  );
}

Uri resolveNexaHttpNativeManifestUri({
  required String packageVersion,
  required Map<String, String> environment,
}) {
  final manifestPath = environment[_manifestPathEnvironmentVariable]?.trim();
  if (manifestPath != null && manifestPath.isNotEmpty) {
    return File(manifestPath).absolute.uri;
  }

  final releaseBaseUrl =
      environment[_releaseBaseUrlEnvironmentVariable]?.trim();
  final base = releaseBaseUrl != null && releaseBaseUrl.isNotEmpty
      ? releaseBaseUrl
      : '$_defaultReleaseBaseUrl/v$packageVersion';
  return Uri.parse('$base/$_manifestFileName');
}

NexaHttpNativeArtifactResolutionMode
    resolveNexaHttpNativeArtifactResolutionMode({
  required Map<String, String> environment,
  NexaHttpNativeArtifactResolutionMode defaultMode =
      NexaHttpNativeArtifactResolutionMode.releaseConsumer,
}) {
  final configured =
      environment[_artifactResolutionModeEnvironmentVariable]?.trim();
  if (configured == null || configured.isEmpty) {
    return defaultMode;
  }

  return switch (configured) {
    'workspace-dev' => NexaHttpNativeArtifactResolutionMode.workspaceDev,
    'release-consumer' =>
      NexaHttpNativeArtifactResolutionMode.releaseConsumer,
    _ => throw StateError(
        'Unsupported $_artifactResolutionModeEnvironmentVariable value '
        '"$configured". Expected "workspace-dev" or "release-consumer".',
      ),
  };
}

NexaHttpNativeArtifactResolutionMode
    defaultNexaHttpNativeArtifactResolutionMode({
  required Uri packageRoot,
  String? defaultSourceDir,
}) {
  final packagePath = Directory.fromUri(packageRoot).absolute.path;
  if (_looksLikePubCachePath(packagePath)) {
    return NexaHttpNativeArtifactResolutionMode.releaseConsumer;
  }
  if (defaultSourceDir != null &&
      defaultSourceDir.isNotEmpty &&
      Directory(defaultSourceDir).existsSync()) {
    return NexaHttpNativeArtifactResolutionMode.workspaceDev;
  }
  return NexaHttpNativeArtifactResolutionMode.releaseConsumer;
}

String packageVersionForRoot(Uri packageRoot) {
  final pubspecFile = File.fromUri(packageRoot.resolve('pubspec.yaml'));
  final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
  return (pubspec['version'] as String?)?.trim() ??
      (throw StateError('pubspec.yaml is missing a version field.'));
}

Future<File?> _resolveExplicitFile({
  required Map<String, String> environment,
  required String libPathEnvironmentVariable,
}) async {
  final explicitPath = environment[libPathEnvironmentVariable]?.trim();
  if (explicitPath == null || explicitPath.isEmpty) {
    return null;
  }

  final explicitFile = File(explicitPath);
  if (!await explicitFile.exists()) {
    throw StateError(
      'Native library override $libPathEnvironmentVariable points to a missing file: $explicitPath',
    );
  }
  return explicitFile.absolute;
}

Future<File?> _resolveSourceDirOverride({
  required Map<String, String> environment,
  required String sourceDirEnvironmentVariable,
  required SourceDirCandidatesBuilder sourceDirCandidates,
  required String libPathEnvironmentVariable,
}) async {
  final sourceDir = environment[sourceDirEnvironmentVariable]?.trim();
  if (sourceDir == null || sourceDir.isEmpty) {
    return null;
  }

  final builtArtifact = await _resolveFromSourceDir(
    sourceDir,
    sourceDirCandidates,
  );
  if (builtArtifact != null) {
    return builtArtifact;
  }

  throw StateError(
    'Native source override $sourceDirEnvironmentVariable did not yield a built artifact. '
    'Build the crate first or use $libPathEnvironmentVariable.',
  );
}

Future<File?> _resolveDefaultSourceDir({
  required String defaultSourceDir,
  required SourceDirCandidatesBuilder sourceDirCandidates,
  required SourceDirBuilder? buildDefaultSourceDir,
}) async {
  final discovered = await _resolveFromSourceDir(
    defaultSourceDir,
    sourceDirCandidates,
  );
  if (discovered != null) {
    return discovered;
  }

  if (buildDefaultSourceDir == null) {
    return null;
  }

  await buildDefaultSourceDir(defaultSourceDir);
  return _resolveFromSourceDir(defaultSourceDir, sourceDirCandidates);
}

Future<File?> _resolveFromSourceDir(
  String sourceDir,
  SourceDirCandidatesBuilder sourceDirCandidates,
) async {
  for (final candidate in sourceDirCandidates(sourceDir)) {
    final file = File(candidate);
    if (await file.exists()) {
      return file.absolute;
    }
  }
  return null;
}

Future<File> _downloadFromManifest({
  required Uri cacheRoot,
  required String packageVersion,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required Map<String, String> environment,
}) async {
  final manifestUri = resolveNexaHttpNativeManifestUri(
    packageVersion: packageVersion,
    environment: environment,
  );
  final manifest = await NexaHttpNativeAssetManifest.load(manifestUri);
  final entry = manifest.select(
    packageVersion: packageVersion,
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
  );

  final outputDirectory = Directory.fromUri(
    cacheRoot.resolve('nexa_http_native/${entry.cacheKey}/'),
  );
  await outputDirectory.create(recursive: true);

  final destination = File.fromUri(outputDirectory.uri.resolve(entry.fileName));
  if (await destination.exists()) {
    final existingDigest = await sha256OfFile(destination);
    if (existingDigest == entry.sha256) {
      return destination;
    }
    await destination.delete();
  }

  final sourceUri = entry.resolveSourceUri(manifest.baseUri);
  await copyUriToFile(sourceUri, destination);

  final actualDigest = await sha256OfFile(destination);
  if (actualDigest != entry.sha256) {
    throw StateError(
      'Checksum mismatch for $sourceUri. Expected ${entry.sha256}, got $actualDigest.',
    );
  }

  return destination;
}

bool _looksLikePubCachePath(String path) {
  final segments = p
      .split(p.normalize(path))
      .map((segment) => segment.toLowerCase())
      .toList(growable: false);
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (segment == '.pub-cache') {
      return true;
    }
    if (segment == 'pub' &&
        index + 1 < segments.length &&
        segments[index + 1] == 'cache') {
      return true;
    }
  }
  return false;
}
