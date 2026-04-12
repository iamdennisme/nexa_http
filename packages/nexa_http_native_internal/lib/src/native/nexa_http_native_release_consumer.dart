import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'nexa_http_native_target_matrix.dart';

final class NexaHttpNativeGitReleaseRef {
  const NexaHttpNativeGitReleaseRef({
    required this.repositorySlug,
    required this.tag,
  });

  final String repositorySlug;
  final String tag;
}

final class NexaHttpNativeReleaseAsset {
  const NexaHttpNativeReleaseAsset({
    required this.fileName,
    required this.sha256,
    required this.sourceUrl,
  });

  final String fileName;
  final String sha256;
  final Uri sourceUrl;
}

typedef NexaHttpNativeReleaseRefResolver = Future<NexaHttpNativeGitReleaseRef>
    Function(
  String packageRoot,
);
typedef NexaHttpNativeFetchBytes = Future<List<int>> Function(Uri uri);

Future<File> materializeNexaHttpNativeReleaseArtifact({
  required String packageRoot,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  NexaHttpNativeReleaseRefResolver resolveReleaseRef =
      discoverNexaHttpNativeGitReleaseRef,
  NexaHttpNativeFetchBytes fetchBytes = fetchNexaHttpNativeBytes,
}) async {
  final target = findNexaHttpNativeTarget(
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
  );
  if (target == null) {
    throw StateError(
      'Unsupported native target: os=$targetOS architecture=$targetArchitecture sdk=$targetSdk.',
    );
  }

  final releaseRef = await resolveReleaseRef(packageRoot);
  final manifestUri = buildNexaHttpNativeManifestUri(
    repositorySlug: releaseRef.repositorySlug,
    tag: releaseRef.tag,
  );
  final manifestJson = utf8.decode(await fetchBytes(manifestUri));
  final asset = parseNexaHttpNativeReleaseAssetFromManifest(
    manifestJson: manifestJson,
    manifestUri: manifestUri,
    target: target,
  );

  final destination = File(p.join(packageRoot, target.packagedRelativePath));
  if (destination.existsSync()) {
    final currentDigest = await sha256OfFile(destination);
    if (currentDigest == asset.sha256) {
      return destination;
    }
    await destination.delete();
  }

  await destination.parent.create(recursive: true);
  final bytes = await fetchBytes(asset.sourceUrl);
  await destination.writeAsBytes(bytes, flush: true);

  final downloadedDigest = await sha256OfFile(destination);
  if (downloadedDigest != asset.sha256) {
    await destination.delete();
    throw StateError(
      'Checksum mismatch for ${asset.fileName}: expected ${asset.sha256}, got $downloadedDigest.',
    );
  }

  return destination;
}

Uri buildNexaHttpNativeManifestUri({
  required String repositorySlug,
  required String tag,
}) {
  return Uri.https(
    'github.com',
    '/$repositorySlug/releases/download/$tag/nexa_http_native_assets_manifest.json',
  );
}

NexaHttpNativeReleaseAsset parseNexaHttpNativeReleaseAssetFromManifest({
  required String manifestJson,
  required Uri manifestUri,
  required NexaHttpNativeTarget target,
}) {
  final decoded = jsonDecode(manifestJson);
  if (decoded is! Map<String, Object?>) {
    throw StateError('Invalid native asset manifest at $manifestUri.');
  }

  final assets = decoded['assets'];
  if (assets is! List<Object?>) {
    throw StateError(
        'Native asset manifest missing assets list at $manifestUri.');
  }

  for (final entry in assets) {
    if (entry is! Map<String, Object?>) {
      continue;
    }
    if (entry['target_os'] != target.targetOS ||
        entry['target_architecture'] != target.targetArchitecture ||
        entry['target_sdk'] != target.targetSdk) {
      continue;
    }

    final fileName = '${entry['file_name'] ?? ''}'.trim();
    final sha256 = '${entry['sha256'] ?? ''}'.trim();
    final rawSourceUrl = '${entry['source_url'] ?? ''}'.trim();
    if (fileName.isEmpty || sha256.isEmpty || rawSourceUrl.isEmpty) {
      throw StateError(
        'Native asset manifest entry for ${target.releaseAssetFileName} is incomplete at $manifestUri.',
      );
    }
    final sourceUrl = Uri.parse(rawSourceUrl);
    return NexaHttpNativeReleaseAsset(
      fileName: fileName,
      sha256: sha256,
      sourceUrl:
          sourceUrl.hasScheme ? sourceUrl : manifestUri.resolveUri(sourceUrl),
    );
  }

  throw StateError(
    'No released native asset found for os=${target.targetOS} architecture=${target.targetArchitecture} sdk=${target.targetSdk} in $manifestUri.',
  );
}

Future<NexaHttpNativeGitReleaseRef> discoverNexaHttpNativeGitReleaseRef(
  String packageRoot,
) async {
  final repoRoot = findAncestorGitRepositoryRoot(packageRoot);
  if (repoRoot == null) {
    throw StateError(
      'Release-consumer native resolution requires a git checkout for $packageRoot.',
    );
  }

  final repositorySlug = await _discoverGitHubRepositorySlug(repoRoot);
  if (repositorySlug == null) {
    throw StateError(
      'Unsupported git remote for release-consumer native resolution: $repoRoot.',
    );
  }

  final tag = await _runGitAndReadStdout(repoRoot, <String>[
    'describe',
    '--tags',
    '--exact-match',
    'HEAD',
  ]);
  if (tag.isEmpty) {
    throw StateError(
      'Release-consumer native resolution requires the dependency checkout at $repoRoot to be pinned to an exact git tag.',
    );
  }

  return NexaHttpNativeGitReleaseRef(repositorySlug: repositorySlug, tag: tag);
}

Future<String?> _discoverGitHubRepositorySlug(String repoRoot) async {
  final visitedRoots = <String>{};
  var currentRoot = p.normalize(repoRoot);

  while (visitedRoots.add(currentRoot)) {
    final origin = await _tryRunGitAndReadStdout(currentRoot, <String>[
      'config',
      '--get',
      'remote.origin.url',
    ]);
    if (origin == null || origin.isEmpty) {
      return null;
    }

    final repositorySlug = parseGitHubRepositorySlug(origin);
    if (repositorySlug != null) {
      return repositorySlug;
    }

    final nestedRoot = _resolveNestedGitRemoteRoot(
      remoteUrl: origin,
      workingDirectory: currentRoot,
    );
    if (nestedRoot == null) {
      return null;
    }
    currentRoot = nestedRoot;
  }

  return null;
}

String? findAncestorGitRepositoryRoot(String startPath) {
  var current = Directory(startPath).absolute;
  while (true) {
    if (Directory(p.join(current.path, '.git')).existsSync() ||
        File(p.join(current.path, '.git')).existsSync()) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      return null;
    }
    current = parent;
  }
}

String? parseGitHubRepositorySlug(String remoteUrl) {
  final value = remoteUrl.trim();
  final sshMatch =
      RegExp(r'^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$').firstMatch(value);
  if (sshMatch != null) {
    return '${sshMatch.group(1)}/${sshMatch.group(2)}';
  }

  final httpsUri = Uri.tryParse(value);
  if (httpsUri != null && httpsUri.host == 'github.com') {
    final segments =
        httpsUri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.length >= 2) {
      final repo = segments[1].endsWith('.git')
          ? segments[1].substring(0, segments[1].length - 4)
          : segments[1];
      return '${segments[0]}/$repo';
    }
  }

  return null;
}

String? _resolveNestedGitRemoteRoot({
  required String remoteUrl,
  required String workingDirectory,
}) {
  final value = remoteUrl.trim();
  if (value.isEmpty) {
    return null;
  }

  final fileUri = Uri.tryParse(value);
  if (fileUri != null && fileUri.scheme == 'file') {
    return p.normalize(fileUri.toFilePath());
  }

  if (p.isAbsolute(value)) {
    return p.normalize(value);
  }

  if (value.startsWith('.')) {
    return p.normalize(p.join(workingDirectory, value));
  }

  return null;
}

Future<List<int>> fetchNexaHttpNativeBytes(Uri uri) async {
  final client = HttpClient();
  try {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
          return consolidateHttpClientResponseBytes(response);
        }
        if (_isRetriableStatusCode(response.statusCode) &&
            attempt < maxAttempts) {
          await response.drain<void>();
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
          continue;
        }
        throw StateError(
          'Failed to fetch native release asset from $uri: HTTP ${response.statusCode}.',
        );
      } on HandshakeException {
        if (attempt >= maxAttempts) {
          rethrow;
        }
      } on HttpException {
        if (attempt >= maxAttempts) {
          rethrow;
        }
      } on SocketException {
        if (attempt >= maxAttempts) {
          rethrow;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }

    throw StateError('Failed to fetch native release asset from $uri.');
  } finally {
    client.close(force: true);
  }
}

bool _isRetriableStatusCode(int statusCode) {
  return statusCode == HttpStatus.requestTimeout ||
      statusCode == HttpStatus.tooManyRequests ||
      statusCode >= HttpStatus.internalServerError;
}

Future<String> _runGitAndReadStdout(
  String workingDirectory,
  List<String> arguments,
) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Git command failed in $workingDirectory: git ${arguments.join(' ')}\n${result.stdout}${result.stderr}',
    );
  }
  return '${result.stdout}'.trim();
}

Future<String?> _tryRunGitAndReadStdout(
  String workingDirectory,
  List<String> arguments,
) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    return null;
  }
  return '${result.stdout}'.trim();
}

Future<List<int>> consolidateHttpClientResponseBytes(
    HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
