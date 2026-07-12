import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

typedef CandidateFileReader = Stream<List<int>> Function(File file);

final class VerifiedCandidateSet {
  const VerifiedCandidateSet({
    required this.candidateDirectory,
    required this.candidateId,
    required this.sdkRef,
    required this.digest,
    required this.artifactDigests,
    required this.artifactFiles,
  });

  final Directory candidateDirectory;
  final String candidateId;
  final String sdkRef;
  final String digest;
  final Map<String, String> artifactDigests;
  final Map<String, File> artifactFiles;
}

Future<VerifiedCandidateSet> verifyCandidateSet(
  Directory candidateDirectory, {
  required String candidateId,
  required String expectedDigest,
  required String sdkRef,
  CandidateDigestCache? digestCache,
}) async {
  if (candidateId.trim().isEmpty || sdkRef.trim().isEmpty) {
    throw StateError('Candidate ID and SDK ref are required');
  }
  final normalizedExpectedDigest = expectedDigest.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedExpectedDigest)) {
    throw StateError('Candidate digest must be a SHA-256 value');
  }
  final artifactDigests = await verifyCandidateManifestAndChecksums(
    candidateDirectory,
    digestCache: digestCache,
  );
  final entries = artifactDigests.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final actualDigest = sha256
      .convert(
        utf8.encode(
          entries.map((entry) => '${entry.key}:${entry.value}\n').join(),
        ),
      )
      .toString();
  if (actualDigest != normalizedExpectedDigest) {
    throw StateError(
      'candidate-set digest mismatch: '
      'expected=$normalizedExpectedDigest actual=$actualDigest',
    );
  }
  return VerifiedCandidateSet(
    candidateDirectory: Directory(
      p.normalize(p.absolute(candidateDirectory.path)),
    ),
    candidateId: candidateId,
    sdkRef: sdkRef,
    digest: actualDigest,
    artifactDigests: artifactDigests,
    artifactFiles: Map<String, File>.unmodifiable(<String, File>{
      for (final target in nexaHttpSupportedNativeTargets)
        target.releaseAssetFileName: File(
          p.join(candidateDirectory.path, target.releaseAssetFileName),
        ),
    }),
  );
}

Future<Map<String, String>> verifyCandidateManifestAndChecksums(
  Directory candidateDirectory, {
  CandidateDigestCache? digestCache,
}) async {
  final artifacts = validateCandidateArtifactCompleteness(candidateDirectory);
  final manifestFile = File(
    p.join(candidateDirectory.path, 'nexa_http_native_assets_manifest.json'),
  );
  final checksumsFile = File(p.join(candidateDirectory.path, 'SHA256SUMS'));
  if (!manifestFile.existsSync() || !checksumsFile.existsSync()) {
    throw StateError(
      'Candidate requires nexa_http_native_assets_manifest.json and SHA256SUMS',
    );
  }

  final manifest = jsonDecode(await manifestFile.readAsString());
  if (manifest is! Map<String, Object?> || manifest['assets'] is! List) {
    throw StateError('Invalid candidate manifest structure');
  }
  final manifestDigests = <String, String>{};
  for (final rawAsset in manifest['assets']! as List<Object?>) {
    if (rawAsset is! Map) {
      throw StateError('Invalid candidate manifest asset entry');
    }
    final fileName = rawAsset['file_name'];
    final digest = rawAsset['sha256'];
    if (fileName is! String || digest is! String) {
      throw StateError('Candidate manifest asset is missing file_name/sha256');
    }
    if (manifestDigests.containsKey(fileName)) {
      throw StateError('Duplicate candidate manifest asset: $fileName');
    }
    manifestDigests[fileName] = digest.toLowerCase();
  }

  final checksumDigests = <String, String>{};
  for (final line in await checksumsFile.readAsLines()) {
    if (line.trim().isEmpty) {
      continue;
    }
    final match = RegExp(r'^([0-9A-Fa-f]{64})\s{2}(.+)$').firstMatch(line);
    if (match == null) {
      throw StateError('Invalid SHA256SUMS line: $line');
    }
    final fileName = match.group(2)!;
    if (checksumDigests.containsKey(fileName)) {
      throw StateError('Duplicate SHA256SUMS entry: $fileName');
    }
    checksumDigests[fileName] = match.group(1)!.toLowerCase();
  }

  final cache = digestCache ?? CandidateDigestCache();
  final verifiedDigests = <String, String>{};
  for (final artifact in artifacts) {
    final fileName = p.basename(artifact.path);
    final actualDigest = await cache.digest(artifact);
    final manifestDigest = manifestDigests[fileName];
    final checksumDigest = checksumDigests[fileName];
    if (manifestDigest != actualDigest || checksumDigest != actualDigest) {
      throw StateError(
        'Candidate checksum mismatch for $fileName: '
        'actual=$actualDigest manifest=$manifestDigest sums=$checksumDigest',
      );
    }
    verifiedDigests[fileName] = actualDigest;
  }
  final expectedFileNames = artifacts
      .map((file) => p.basename(file.path))
      .toSet();
  if (manifestDigests.keys.toSet().difference(expectedFileNames).isNotEmpty ||
      expectedFileNames.difference(manifestDigests.keys.toSet()).isNotEmpty ||
      checksumDigests.keys.toSet().difference(expectedFileNames).isNotEmpty ||
      expectedFileNames.difference(checksumDigests.keys.toSet()).isNotEmpty) {
    throw StateError('Candidate manifest/checksum coverage mismatch');
  }
  return Map<String, String>.unmodifiable(verifiedDigests);
}

List<File> validateCandidateArtifactCompleteness(Directory candidateDirectory) {
  final artifacts = <File>[];
  final missing = <String>[];
  for (final target in nexaHttpSupportedNativeTargets) {
    final file = File(
      p.join(candidateDirectory.path, target.releaseAssetFileName),
    );
    if (!file.existsSync()) {
      missing.add(target.releaseAssetFileName);
    } else {
      artifacts.add(file);
    }
  }
  if (missing.isNotEmpty) {
    missing.sort();
    throw StateError('Candidate is missing canonical artifacts: $missing');
  }
  final allowedFileNames = <String>{
    for (final target in nexaHttpSupportedNativeTargets)
      target.releaseAssetFileName,
    'nexa_http_native_assets_manifest.json',
    'SHA256SUMS',
  };
  final unknown =
      candidateDirectory
          .listSync(followLinks: false)
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .where((fileName) => !allowedFileNames.contains(fileName))
          .toList()
        ..sort();
  if (unknown.isNotEmpty) {
    throw StateError('Candidate contains unknown artifacts: $unknown');
  }
  return List<File>.unmodifiable(artifacts);
}

final class CandidateDigestCache {
  CandidateDigestCache({CandidateFileReader? openRead})
    : _openRead = openRead ?? ((file) => file.openRead());

  final CandidateFileReader _openRead;
  final Map<String, Future<String>> _digests = <String, Future<String>>{};

  Future<String> digest(File file) {
    final path = p.normalize(p.absolute(file.path));
    return _digests[path] ??= sha256
        .bind(_openRead(file))
        .first
        .then((digest) => digest.toString());
  }
}
