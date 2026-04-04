import 'dart:io';

import 'package:path/path.dart' as p;

import 'nexa_http_native_digest.dart';
import 'nexa_http_native_file_transfer.dart';
import 'nexa_http_native_manifest.dart';

const _manifestPathEnvironmentVariable = 'NEXA_HTTP_NATIVE_MANIFEST_PATH';
const _releaseBaseUrlEnvironmentVariable = 'NEXA_HTTP_NATIVE_RELEASE_BASE_URL';
const _releaseIdentityEnvironmentVariable = 'NEXA_HTTP_NATIVE_RELEASE_IDENTITY';
const _defaultReleaseBaseUrl =
    'https://github.com/iamdennisme/nexa_http/releases/download';
const _manifestFileName = 'nexa_http_native_assets_manifest.json';
const _artifactResolutionModeEnvironmentVariable =
    'NEXA_HTTP_NATIVE_ARTIFACT_MODE';

enum NexaHttpNativeArtifactResolutionMode { workspaceDev, releaseConsumer }

typedef SourceDirCandidatesBuilder =
    Iterable<String> Function(String sourceDir);
typedef SourceDirBuilder = Future<void> Function(String sourceDir);

Future<File> resolveNexaHttpNativeArtifactFile({
  required Uri packageRoot,
  required Uri cacheRoot,
  required NexaHttpNativeArtifactResolutionMode mode,
  required String? releaseIdentity,
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

  if (mode == NexaHttpNativeArtifactResolutionMode.workspaceDev) {
    final packagedFile = File.fromUri(
      packageRoot.resolve(packagedRelativePath),
    );
    if (await packagedFile.exists()) {
      return packagedFile;
    }
  }

  return _downloadFromManifest(
    packageRoot: packageRoot,
    cacheRoot: cacheRoot,
    releaseIdentity: releaseIdentity,
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    environment: environment,
  );
}

Uri resolveNexaHttpNativeManifestUri({
  required String? releaseIdentity,
  required Map<String, String> environment,
}) {
  final manifestPath = environment[_manifestPathEnvironmentVariable]?.trim();
  if (manifestPath != null && manifestPath.isNotEmpty) {
    return File(manifestPath).absolute.uri;
  }

  final releaseBaseUrl = environment[_releaseBaseUrlEnvironmentVariable]
      ?.trim();
  if (releaseBaseUrl != null && releaseBaseUrl.isNotEmpty) {
    return Uri.parse('$releaseBaseUrl/$_manifestFileName');
  }

  final normalizedIdentity =
      releaseIdentity == null || releaseIdentity.trim().isEmpty
      ? null
      : normalizeReleaseIdentity(releaseIdentity);
  if (normalizedIdentity == null) {
    throw StateError(
      'Missing release identity for release-consumer manifest resolution. '
      'Set $_releaseIdentityEnvironmentVariable, $_releaseBaseUrlEnvironmentVariable, or $_manifestPathEnvironmentVariable.',
    );
  }

  return Uri.parse(
    '$_defaultReleaseBaseUrl/$normalizedIdentity/$_manifestFileName',
  );
}

NexaHttpNativeArtifactResolutionMode
resolveNexaHttpNativeArtifactResolutionMode({
  required Map<String, String> environment,
  NexaHttpNativeArtifactResolutionMode defaultMode =
      NexaHttpNativeArtifactResolutionMode.releaseConsumer,
}) {
  final configured = environment[_artifactResolutionModeEnvironmentVariable]
      ?.trim();
  if (configured == null || configured.isEmpty) {
    return defaultMode;
  }

  return switch (configured) {
    'workspace-dev' => NexaHttpNativeArtifactResolutionMode.workspaceDev,
    'release-consumer' => NexaHttpNativeArtifactResolutionMode.releaseConsumer,
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

String normalizeReleaseIdentity(String releaseIdentity) {
  final normalized = releaseIdentity.trim();
  if (normalized.isEmpty) {
    throw StateError('Release identity must not be empty.');
  }
  if (normalized.startsWith('refs/tags/')) {
    return normalized.substring('refs/tags/'.length);
  }
  if (normalized.startsWith('refs/heads/')) {
    return normalized.substring('refs/heads/'.length);
  }
  return normalized;
}

String releaseVersionForIdentity(String releaseIdentity) {
  final normalized = normalizeReleaseIdentity(releaseIdentity);
  return normalized.startsWith('v') ? normalized.substring(1) : normalized;
}

String? configuredNexaHttpNativeReleaseIdentity({
  required Map<String, String> environment,
}) {
  final explicit =
      environment[_releaseIdentityEnvironmentVariable]?.trim() ??
      environment['NEXA_HTTP_NATIVE_RELEASE_REF']?.trim();
  if (explicit == null || explicit.isEmpty) {
    return null;
  }
  return normalizeReleaseIdentity(explicit);
}

String? resolveNexaHttpNativeReleaseIdentity({
  required Uri packageRoot,
  required Map<String, String> environment,
}) {
  final configured = configuredNexaHttpNativeReleaseIdentity(
    environment: environment,
  );
  if (configured != null) {
    return configured;
  }

  final packagePath = Directory.fromUri(packageRoot).path;
  final result = Process.runSync('git', <String>[
    '-C',
    packagePath,
    'tag',
    '--points-at',
    'HEAD',
  ]);
  if (result.exitCode != 0) {
    return null;
  }

  final tags = '${result.stdout}'
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(normalizeReleaseIdentity)
      .toList(growable: false);
  if (tags.isEmpty) {
    return null;
  }
  if (tags.length > 1) {
    throw StateError(
      'Multiple git tags point at HEAD: ${tags.join(', ')}. '
      'Set $_releaseIdentityEnvironmentVariable explicitly.',
    );
  }
  return tags.single;
}

bool _hasManifestPathOverride(Map<String, String> environment) {
  final manifestPath = environment[_manifestPathEnvironmentVariable]?.trim();
  return manifestPath != null && manifestPath.isNotEmpty;
}

bool _hasReleaseBaseUrlOverride(Map<String, String> environment) {
  final releaseBaseUrl = environment[_releaseBaseUrlEnvironmentVariable]
      ?.trim();
  return releaseBaseUrl != null && releaseBaseUrl.isNotEmpty;
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
  if (buildDefaultSourceDir != null) {
    await buildDefaultSourceDir(defaultSourceDir);
    final rebuilt = await _resolveFromSourceDir(
      defaultSourceDir,
      sourceDirCandidates,
    );
    if (rebuilt != null) {
      return rebuilt;
    }
  }

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
  required Uri packageRoot,
  required Uri cacheRoot,
  required String? releaseIdentity,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required Map<String, String> environment,
}) async {
  var effectiveReleaseIdentity =
      releaseIdentity == null || releaseIdentity.trim().isEmpty
      ? configuredNexaHttpNativeReleaseIdentity(environment: environment)
      : normalizeReleaseIdentity(releaseIdentity);
  final requiresDerivedReleaseIdentity =
      !_hasManifestPathOverride(environment) &&
      !_hasReleaseBaseUrlOverride(environment);
  if (effectiveReleaseIdentity == null && requiresDerivedReleaseIdentity) {
    effectiveReleaseIdentity = resolveNexaHttpNativeReleaseIdentity(
      packageRoot: packageRoot,
      environment: environment,
    );
  }

  final manifestUri = resolveNexaHttpNativeManifestUri(
    releaseIdentity: effectiveReleaseIdentity,
    environment: environment,
  );
  final manifest = await NexaHttpNativeAssetManifest.load(manifestUri);
  final entry = manifest.select(
    expectedReleaseVersion: effectiveReleaseIdentity == null
        ? null
        : releaseVersionForIdentity(effectiveReleaseIdentity),
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
