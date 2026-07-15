import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

typedef NexaHttpNativeReleaseRefResolver =
    Future<NexaHttpNativeGitReleaseRef> Function(String packageRoot);
typedef NexaHttpNativeFetchStream = Future<Stream<List<int>>> Function(Uri uri);

final class NexaHttpNativeArtifactException implements Exception {
  const NexaHttpNativeArtifactException({
    required this.stage,
    required this.targetOS,
    required this.targetArchitecture,
    required this.targetSdk,
    required this.sdkRef,
    required this.expectedAction,
    required this.underlyingError,
  });

  final String stage;
  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String sdkRef;
  final String expectedAction;
  final Object underlyingError;

  @override
  String toString() {
    return 'NexaHttpNativeArtifactException: nexa_http native artifact resolution failed. '
        'stage=$stage; platform=$targetOS; architecture=$targetArchitecture; '
        'target_sdk=${targetSdk ?? 'none'}; sdk_ref=$sdkRef; '
        'expected_action=$expectedAction; underlying_error=$underlyingError';
  }
}

Future<File> materializeNexaHttpNativeReleaseArtifact({
  required String packageRoot,
  required String outputDirectory,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  NexaHttpNativeReleaseRefResolver resolveReleaseRef =
      discoverNexaHttpNativeGitReleaseRef,
  NexaHttpNativeFetchStream fetchStream = fetchNexaHttpNativeStream,
}) async {
  final target = findNexaHttpNativeTarget(
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
  );
  if (target == null) {
    _throwNexaHttpNativeArtifactException(
      stage: 'native target resolution',
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      targetSdk: targetSdk,
      sdkRef: 'unknown',
      underlyingError: StateError(
        'Unsupported native target: os=$targetOS architecture=$targetArchitecture sdk=$targetSdk.',
      ),
    );
  }

  final releaseRef = await _runNexaHttpNativeArtifactStage(
    stage: 'release ref resolution',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: 'unknown',
    action: () => resolveReleaseRef(packageRoot),
  );
  final manifestUri = buildNexaHttpNativeManifestUri(
    repositorySlug: releaseRef.repositorySlug,
    tag: releaseRef.tag,
  );
  final sdkRef = '${releaseRef.repositorySlug}@${releaseRef.tag}';
  final manifestJson = await _runNexaHttpNativeArtifactStage(
    stage: 'artifact download',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: sdkRef,
    action: () async =>
        utf8.decoder.bind(await fetchStream(manifestUri)).join(),
  );
  final asset = _runNexaHttpNativeArtifactStageSync(
    stage: 'artifact verification',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: sdkRef,
    action: () => parseNexaHttpNativeReleaseAssetFromManifest(
      manifestJson: manifestJson,
      manifestUri: manifestUri,
      target: target,
    ),
  );

  final destination = File(
    p.join(outputDirectory, target.materializationRelativePath('release')),
  );
  return _runNexaHttpNativeArtifactStage(
    stage: 'artifact verification',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: sdkRef,
    action: () => withNexaHttpNativeArtifactLock(destination, () async {
      if (await _fileHasDigest(destination, asset.sha256)) {
        return destination;
      }
      final stream = await _runNexaHttpNativeArtifactStage(
        stage: 'artifact download',
        targetOS: targetOS,
        targetArchitecture: targetArchitecture,
        targetSdk: targetSdk,
        sdkRef: sdkRef,
        action: () => fetchStream(asset.sourceUrl),
      );
      return _materializeStreamAtomically(
        destination: destination,
        stream: stream,
        expectedDigest: asset.sha256,
      );
    }),
  );
}

Future<File> materializeNexaHttpNativeCandidateArtifact({
  required String outputDirectory,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required String candidateDirectory,
  required String candidateRef,
}) async {
  final target = findNexaHttpNativeTarget(
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
  );
  if (target == null) {
    _throwNexaHttpNativeArtifactException(
      stage: 'native target resolution',
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      targetSdk: targetSdk,
      sdkRef: candidateRef,
      underlyingError: StateError('Unsupported candidate native target'),
    );
  }
  final candidateRoot = Directory(candidateDirectory).absolute;
  final manifestFile = File(
    p.join(candidateRoot.path, 'nexa_http_native_assets_manifest.json'),
  );
  final manifestJson = await _runNexaHttpNativeArtifactStage(
    stage: 'candidate manifest read',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: candidateRef,
    action: manifestFile.readAsString,
  );
  final asset = _runNexaHttpNativeArtifactStageSync(
    stage: 'candidate verification',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: candidateRef,
    action: () => parseNexaHttpNativeReleaseAssetFromManifest(
      manifestJson: manifestJson,
      manifestUri: manifestFile.uri,
      target: target,
    ),
  );
  final source = File(p.join(candidateRoot.path, asset.fileName));
  final sourceDigest = await _runNexaHttpNativeArtifactStage(
    stage: 'candidate verification',
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: candidateRef,
    action: () => sha256OfFile(source),
  );
  if (sourceDigest != asset.sha256) {
    _throwNexaHttpNativeArtifactException(
      stage: 'candidate verification',
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      targetSdk: targetSdk,
      sdkRef: candidateRef,
      underlyingError: StateError(
        'Checksum mismatch for ${asset.fileName}: expected ${asset.sha256}, got $sourceDigest.',
      ),
    );
  }
  final destination = File(
    p.join(outputDirectory, target.materializationRelativePath('candidate')),
  );
  return withNexaHttpNativeArtifactLock(destination, () async {
    if (await _fileHasDigest(destination, sourceDigest)) {
      return destination;
    }
    return _materializeStreamAtomically(
      destination: destination,
      stream: source.openRead(),
      expectedDigest: sourceDigest,
    );
  });
}

final Map<String, Future<void>> _artifactQueues = <String, Future<void>>{};

Future<T> withNexaHttpNativeArtifactLock<T>(
  File destination,
  Future<T> Function() action,
) async {
  final key = destination.absolute.path;
  final previous = _artifactQueues[key] ?? Future<void>.value();
  final gate = Completer<void>();
  final current = gate.future;
  _artifactQueues[key] = current;
  try {
    await previous.catchError((_) {});
  } catch (_) {}
  await destination.parent.create(recursive: true);
  final lock = await File(
    '${destination.path}.lock',
  ).open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.exclusive);
    return await action();
  } finally {
    await lock.unlock();
    await lock.close();
    gate.complete();
    if (identical(_artifactQueues[key], current)) {
      _artifactQueues.remove(key);
    }
  }
}

Future<bool> _fileHasDigest(File file, String expectedDigest) async {
  return file.existsSync() && await sha256OfFile(file) == expectedDigest;
}

Future<File> _materializeStreamAtomically({
  required File destination,
  required Stream<List<int>> stream,
  required String expectedDigest,
}) async {
  final temporary = File(
    '${destination.path}.tmp.${pid}.${DateTime.now().microsecondsSinceEpoch}.${Random.secure().nextInt(1 << 32)}',
  );
  final output = temporary.openWrite(mode: FileMode.writeOnly);
  final digestSink = _DigestSink();
  final digestInput = sha256.startChunkedConversion(digestSink);
  try {
    await for (final chunk in stream) {
      digestInput.add(chunk);
      output.add(chunk);
    }
    digestInput.close();
    await output.flush();
    await output.close();
    final actualDigest = digestSink.value.toString();
    if (actualDigest != expectedDigest) {
      throw StateError(
        'Checksum mismatch: expected $expectedDigest, got $actualDigest.',
      );
    }
    await _replaceFile(destination, temporary);
    return destination;
  } catch (_) {
    digestInput.close();
    await output.close();
    if (temporary.existsSync()) {
      await temporary.delete();
    }
    rethrow;
  }
}

Future<void> _replaceFile(File destination, File temporary) async {
  if (!destination.existsSync()) {
    await temporary.rename(destination.path);
    return;
  }
  final backup = File(
    '${destination.path}.old.${pid}.${DateTime.now().microsecondsSinceEpoch}',
  );
  await destination.rename(backup.path);
  try {
    await temporary.rename(destination.path);
    await backup.delete();
  } catch (_) {
    if (!destination.existsSync() && backup.existsSync()) {
      await backup.rename(destination.path);
    }
    rethrow;
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value ?? (throw StateError('Digest is not complete.'));
  @override
  void add(Digest data) => _value = data;
  @override
  void close() {}
}

Future<T> _runNexaHttpNativeArtifactStage<T>({
  required String stage,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required String sdkRef,
  required Future<T> Function() action,
}) async {
  try {
    return await action();
  } on NexaHttpNativeArtifactException {
    rethrow;
  } catch (error, stackTrace) {
    _throwNexaHttpNativeArtifactException(
      stage: stage,
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      targetSdk: targetSdk,
      sdkRef: sdkRef,
      underlyingError: error,
      stackTrace: stackTrace,
    );
  }
}

T _runNexaHttpNativeArtifactStageSync<T>({
  required String stage,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required String sdkRef,
  required T Function() action,
}) {
  try {
    return action();
  } on NexaHttpNativeArtifactException {
    rethrow;
  } catch (error, stackTrace) {
    _throwNexaHttpNativeArtifactException(
      stage: stage,
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      targetSdk: targetSdk,
      sdkRef: sdkRef,
      underlyingError: error,
      stackTrace: stackTrace,
    );
  }
}

Never _throwNexaHttpNativeArtifactException({
  required String stage,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  required String sdkRef,
  required Object underlyingError,
  StackTrace? stackTrace,
}) {
  final exception = NexaHttpNativeArtifactException(
    stage: stage,
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
    sdkRef: sdkRef,
    expectedAction:
        'Use a nexa_http git tag with published native release assets, then rerun flutter pub get and flutter build/run. If the failure persists, file an issue with this full message.',
    underlyingError: underlyingError,
  );
  if (stackTrace != null) {
    Error.throwWithStackTrace(exception, stackTrace);
  }
  throw exception;
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
      'Native asset manifest missing assets list at $manifestUri.',
    );
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
      sourceUrl: sourceUrl.hasScheme
          ? sourceUrl
          : manifestUri.resolveUri(sourceUrl),
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

Future<String> _discoverGitHubRepositorySlug(String repoRoot) async {
  final origin = await _runGitAndReadStdout(repoRoot, <String>[
    'config',
    '--get',
    'remote.origin.url',
  ]);
  final directSlug = parseGitHubRepositorySlug(origin);
  if (directSlug != null) {
    return directSlug;
  }

  if (!p.isAbsolute(origin) || !Directory(origin).existsSync()) {
    throw StateError(
      'Unsupported git remote for release-consumer native resolution: $origin.',
    );
  }
  final cacheOrigin = await _runGitAndReadStdout(origin, <String>[
    'config',
    '--get',
    'remote.origin.url',
  ]);
  final cacheSlug = parseGitHubRepositorySlug(cacheOrigin);
  if (cacheSlug == null) {
    throw StateError(
      'Unsupported pub cache git remote for release-consumer native resolution: '
      '$origin -> $cacheOrigin.',
    );
  }
  return cacheSlug;
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
  final sshMatch = RegExp(
    r'^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$',
  ).firstMatch(value);
  if (sshMatch != null) {
    return '${sshMatch.group(1)}/${sshMatch.group(2)}';
  }

  final httpsUri = Uri.tryParse(value);
  if (httpsUri != null && httpsUri.host == 'github.com') {
    final segments = httpsUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length >= 2) {
      final repo = segments[1].endsWith('.git')
          ? segments[1].substring(0, segments[1].length - 4)
          : segments[1];
      return '${segments[0]}/$repo';
    }
  }

  return null;
}

Future<Stream<List<int>>> fetchNexaHttpNativeStream(Uri uri) async {
  final client = HttpClient();
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    client.close(force: true);
    throw StateError(
      'Failed to fetch native release asset from $uri: HTTP ${response.statusCode}.',
    );
  }
  return (() async* {
    try {
      yield* response;
    } finally {
      client.close(force: true);
    }
  })();
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
