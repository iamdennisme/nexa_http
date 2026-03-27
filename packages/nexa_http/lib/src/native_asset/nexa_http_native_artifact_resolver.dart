import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

const _manifestPathEnvironmentVariable = 'NEXA_HTTP_NATIVE_MANIFEST_PATH';
const _releaseBaseUrlEnvironmentVariable = 'NEXA_HTTP_NATIVE_RELEASE_BASE_URL';
const _defaultReleaseBaseUrl =
    'https://github.com/iamdennisme/rust_net/releases/download';
const _manifestFileName = 'nexa_http_native_assets_manifest.json';

typedef SourceDirCandidatesBuilder = Iterable<String> Function(String sourceDir);
typedef SourceDirBuilder = Future<void> Function(String sourceDir);

Future<File> resolveNexaHttpNativeArtifactFile({
  required Uri packageRoot,
  required Uri cacheRoot,
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
  final explicitPath = environment[libPathEnvironmentVariable]?.trim();
  if (explicitPath != null && explicitPath.isNotEmpty) {
    final explicitFile = File(explicitPath);
    if (!await explicitFile.exists()) {
      throw StateError(
        'Native library override $libPathEnvironmentVariable points to a missing file: $explicitPath',
      );
    }
    return explicitFile.absolute;
  }

  final sourceDir = environment[sourceDirEnvironmentVariable]?.trim();
  if (sourceDir != null && sourceDir.isNotEmpty) {
    for (final candidate in sourceDirCandidates(sourceDir)) {
      final file = File(candidate);
      if (await file.exists()) {
        return file.absolute;
      }
    }
    throw StateError(
      'Native source override $sourceDirEnvironmentVariable did not yield a built artifact. '
      'Build the crate first or use $libPathEnvironmentVariable.',
    );
  }

  final packagedFile = File.fromUri(packageRoot.resolve(packagedRelativePath));
  if (await packagedFile.exists()) {
    return packagedFile;
  }

  if (defaultSourceDir != null && defaultSourceDir.isNotEmpty) {
    final discovered = await _resolveFromSourceDir(
      defaultSourceDir,
      sourceDirCandidates,
    );
    if (discovered != null) {
      return discovered;
    }

    if (buildDefaultSourceDir != null) {
      await buildDefaultSourceDir(defaultSourceDir);
      final built = await _resolveFromSourceDir(
        defaultSourceDir,
        sourceDirCandidates,
      );
      if (built != null) {
        return built;
      }
    }
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
  final manifestUri = _resolveManifestUri(
    packageVersion: packageVersion,
    environment: environment,
  );
  final manifest = await _NexaHttpNativeAssetManifest.load(manifestUri);
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
  await _copyUriToFile(sourceUri, destination);

  final actualDigest = await sha256OfFile(destination);
  if (actualDigest != entry.sha256) {
    throw StateError(
      'Checksum mismatch for $sourceUri. Expected ${entry.sha256}, got $actualDigest.',
    );
  }

  return destination;
}

Uri _resolveManifestUri({
  required String packageVersion,
  required Map<String, String> environment,
}) {
  final manifestPath = environment[_manifestPathEnvironmentVariable]?.trim();
  if (manifestPath != null && manifestPath.isNotEmpty) {
    return File(manifestPath).absolute.uri;
  }

  final releaseBaseUrl = environment[_releaseBaseUrlEnvironmentVariable]?.trim();
  final base = releaseBaseUrl != null && releaseBaseUrl.isNotEmpty
      ? releaseBaseUrl
      : '$_defaultReleaseBaseUrl/v$packageVersion';
  return Uri.parse('$base/$_manifestFileName');
}

Uri resolveNexaHttpNativeManifestUri({
  required String packageVersion,
  required Map<String, String> environment,
}) {
  return _resolveManifestUri(
    packageVersion: packageVersion,
    environment: environment,
  );
}

String packageVersionForRoot(Uri packageRoot) {
  final pubspecFile = File.fromUri(packageRoot.resolve('pubspec.yaml'));
  final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
  return (pubspec['version'] as String?)?.trim() ??
      (throw StateError('pubspec.yaml is missing a version field.'));
}

String sha256OfString(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

Future<String> sha256OfFile(File file) async {
  final digest = sha256.convert(await file.readAsBytes());
  return digest.toString();
}

Future<void> _copyUriToFile(Uri sourceUri, File destination) async {
  switch (sourceUri.scheme) {
    case 'file':
    case '':
      final source = File.fromUri(
        sourceUri.scheme.isEmpty ? sourceUri.replace(scheme: 'file') : sourceUri,
      );
      await destination.parent.create(recursive: true);
      await source.copy(destination.path);
      return;
    case 'http':
    case 'https':
      final client = HttpClient();
      try {
        final request = await client.getUrl(sourceUri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Failed to download $sourceUri: ${response.statusCode}',
            uri: sourceUri,
          );
        }
        await destination.parent.create(recursive: true);
        await response.pipe(destination.openWrite());
      } finally {
        client.close(force: true);
      }
      return;
    default:
      throw UnsupportedError(
        'Unsupported native asset URI scheme: ${sourceUri.scheme}',
      );
  }
}

final class _NexaHttpNativeAssetManifest {
  const _NexaHttpNativeAssetManifest({
    required this.baseUri,
    required this.packageVersion,
    required this.entries,
  });

  final Uri baseUri;
  final String packageVersion;
  final List<_NexaHttpNativeAssetManifestEntry> entries;

  static Future<_NexaHttpNativeAssetManifest> load(Uri uri) async {
    final raw = await _readUriAsString(uri);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Native asset manifest must be a JSON object.');
    }

    final entriesJson = json['assets'];
    if (entriesJson is! List) {
      throw FormatException('Native asset manifest is missing the "assets" list.');
    }

    return _NexaHttpNativeAssetManifest(
      baseUri: uri,
      packageVersion: (json['package_version'] as String?)?.trim() ?? '',
      entries: entriesJson
          .map((entry) => _NexaHttpNativeAssetManifestEntry.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList(growable: false),
    );
  }

  _NexaHttpNativeAssetManifestEntry select({
    required String packageVersion,
    required String targetOS,
    required String targetArchitecture,
    required String? targetSdk,
  }) {
    if (this.packageVersion.isNotEmpty && this.packageVersion != packageVersion) {
      throw StateError(
        'Native asset manifest version mismatch. Expected $packageVersion, got ${this.packageVersion}.',
      );
    }

    final matches = entries.where((entry) {
      if (entry.targetOS != targetOS) {
        return false;
      }
      if (entry.targetArchitecture != targetArchitecture) {
        return false;
      }
      if ((entry.targetSdk ?? '') != (targetSdk ?? '')) {
        return false;
      }
      return true;
    }).toList(growable: false);

    if (matches.isEmpty) {
      throw StateError(
        'No native asset entry matches os=$targetOS arch=$targetArchitecture sdk=${targetSdk ?? '-'}',
      );
    }
    if (matches.length > 1) {
      throw StateError(
        'Multiple native asset entries match os=$targetOS arch=$targetArchitecture sdk=${targetSdk ?? '-'}',
      );
    }
    return matches.single;
  }
}

final class _NexaHttpNativeAssetManifestEntry {
  const _NexaHttpNativeAssetManifestEntry({
    required this.targetOS,
    required this.targetArchitecture,
    required this.targetSdk,
    required this.fileName,
    required this.sourceUrl,
    required this.sha256,
  });

  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String fileName;
  final String sourceUrl;
  final String sha256;

  String get cacheKey => sha256.substring(0, 12);

  static _NexaHttpNativeAssetManifestEntry fromJson(Map<String, dynamic> json) {
    return _NexaHttpNativeAssetManifestEntry(
      targetOS: json['target_os'] as String,
      targetArchitecture: json['target_architecture'] as String,
      targetSdk: (json['target_sdk'] as String?)?.trim(),
      fileName: json['file_name'] as String,
      sourceUrl: (json['source_url'] ?? json['url']) as String,
      sha256: json['sha256'] as String,
    );
  }

  Uri resolveSourceUri(Uri manifestUri) {
    final uri = Uri.parse(sourceUrl);
    if (uri.hasScheme) {
      return uri;
    }
    return manifestUri.resolveUri(uri);
  }
}

Future<String> _readUriAsString(Uri uri) async {
  switch (uri.scheme) {
    case 'file':
    case '':
      return File.fromUri(
        uri.scheme.isEmpty ? uri.replace(scheme: 'file') : uri,
      ).readAsString();
    case 'http':
    case 'https':
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Failed to download $uri: ${response.statusCode}',
            uri: uri,
          );
        }
        return utf8.decode(await response.fold<List<int>>(
          <int>[],
          (buffer, chunk) => buffer..addAll(chunk),
        ));
      } finally {
        client.close(force: true);
      }
    default:
      throw UnsupportedError('Unsupported manifest URI scheme: ${uri.scheme}');
  }
}
