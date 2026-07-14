import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../verification/command.dart';
import '../verification/candidate_set.dart';
import '../verification/model.dart';
import '../verification/native_build_group.dart';
import '../verification/target_matrix.dart';

typedef ReleaseCommitResolver = Future<String> Function(String commitSha);
typedef ReleaseCheckoutHeadResolver = Future<String> Function();
typedef ReleaseCommitMembershipChecker =
    Future<bool> Function(String commitSha);
typedef ReleaseRemoteStateChecker = Future<bool> Function(String name);

enum ReleaseValidationMode { pullRequest, dispatch }

const nexaHttpReleasePackageNames = <String>[
  'nexa_http',
  'nexa_http_native_internal',
  'nexa_http_native_android',
  'nexa_http_native_ios',
  'nexa_http_native_macos',
  'nexa_http_native_windows',
];

final class ReleaseTransactionInput {
  const ReleaseTransactionInput._({
    required this.version,
    required this.tag,
    required this.commitSha,
  });

  factory ReleaseTransactionInput.parse({
    required String version,
    required String commitSha,
  }) {
    final normalizedVersion = version.trim();
    if (version != normalizedVersion || commitSha != commitSha.trim()) {
      throw const FormatException(
        'Release version and commit must not contain surrounding whitespace',
      );
    }
    if (!RegExp(
      r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$',
    ).hasMatch(normalizedVersion)) {
      throw FormatException(
        'Release version must be stable semver without a v prefix: $version',
      );
    }
    final normalizedCommit = commitSha.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(normalizedCommit)) {
      throw FormatException(
        'Release commit must be a full 40-character SHA: $commitSha',
      );
    }
    return ReleaseTransactionInput._(
      version: normalizedVersion,
      tag: 'v$normalizedVersion',
      commitSha: normalizedCommit,
    );
  }

  final String version;
  final String tag;
  final String commitSha;
}

final class ValidatedReleaseTransaction {
  const ValidatedReleaseTransaction({
    required this.input,
    required this.repository,
    required this.manifestBaseUrl,
    required this.packageVersions,
  });

  final ReleaseTransactionInput input;
  final String repository;
  final String manifestBaseUrl;
  final Map<String, String> packageVersions;
}

final class ReleaseCandidateAssembly {
  const ReleaseCandidateAssembly({
    required this.directory,
    required this.digest,
    required this.artifactDigests,
  });

  final Directory directory;
  final String digest;
  final Map<String, String> artifactDigests;
}

final class ValidatedReleasePublisherCandidate {
  const ValidatedReleasePublisherCandidate({
    required this.transaction,
    required this.candidate,
    required this.publicationFiles,
    required this.publicationDigests,
  });

  final ValidatedReleaseTransaction transaction;
  final VerifiedCandidateSet candidate;
  final List<File> publicationFiles;
  final Map<String, String> publicationDigests;
}

abstract interface class ReleasePublicationGateway {
  Future<void> createTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  });

  Future<void> createRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  });

  Future<bool> ownsTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  });

  Future<bool> ownsRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  });

  Future<void> uploadAssets({
    required String repository,
    required String tag,
    required List<File> files,
  });

  Future<Map<String, String>> fetchReleaseAssetDigests({
    required String repository,
    required String tag,
  });

  Future<void> deleteRelease({required String repository, required String tag});

  Future<void> deleteTag({required String repository, required String tag});
}

Future<ValidatedReleaseTransaction> validateReleaseTransaction({
  required String workspaceRoot,
  required String repository,
  required ReleaseTransactionInput input,
  required ReleaseValidationMode mode,
  required ReleaseCommitResolver resolveCommit,
  ReleaseCheckoutHeadResolver? resolveCheckoutHead,
  required ReleaseCommitMembershipChecker isCommitOnMain,
  required ReleaseRemoteStateChecker tagExists,
  required ReleaseRemoteStateChecker releaseExists,
}) async {
  final normalizedRepository = repository.trim();
  if (!RegExp(r'^[^/\s]+/[^/\s]+$').hasMatch(normalizedRepository)) {
    throw FormatException('Repository must use owner/name form: $repository');
  }
  final resolvedCommit = (await resolveCommit(
    input.commitSha,
  )).trim().toLowerCase();
  if (resolvedCommit != input.commitSha) {
    throw StateError(
      'Release commit did not resolve exactly: '
      'expected=${input.commitSha} actual=$resolvedCommit',
    );
  }
  if (mode == ReleaseValidationMode.pullRequest) {
    if (resolveCheckoutHead == null) {
      throw StateError('Pull request validation requires checkout HEAD');
    }
    final checkoutHead = (await resolveCheckoutHead()).trim().toLowerCase();
    if (checkoutHead != input.commitSha) {
      throw StateError(
        'Pull request checkout HEAD mismatch: '
        'expected=${input.commitSha} actual=$checkoutHead',
      );
    }
  }
  if (mode == ReleaseValidationMode.dispatch &&
      !await isCommitOnMain(input.commitSha)) {
    throw StateError('Release commit is not reachable from origin/main');
  }

  final versions = await readNexaHttpPackageVersions(workspaceRoot);
  final mismatches = versions.entries
      .where((entry) => entry.value != input.version)
      .map((entry) => '${entry.key}=${entry.value}')
      .toList(growable: false);
  if (mismatches.isNotEmpty) {
    throw StateError(
      'Release package versions must all equal ${input.version}: $mismatches',
    );
  }
  if (await tagExists(input.tag)) {
    throw StateError('Release tag already exists: ${input.tag}');
  }
  if (await releaseExists(input.tag)) {
    throw StateError('GitHub Release already exists: ${input.tag}');
  }

  return ValidatedReleaseTransaction(
    input: input,
    repository: normalizedRepository,
    manifestBaseUrl:
        'https://github.com/$normalizedRepository/releases/download/${input.tag}',
    packageVersions: Map<String, String>.unmodifiable(versions),
  );
}

Future<Map<String, String>> readNexaHttpPackageVersions(
  String workspaceRoot,
) async {
  final versions = <String, String>{};
  for (final packageName in nexaHttpReleasePackageNames) {
    final pubspec = File(
      p.join(workspaceRoot, 'packages', packageName, 'pubspec.yaml'),
    );
    if (!pubspec.existsSync()) {
      throw StateError(
        'Release package pubspec does not exist: ${pubspec.path}',
      );
    }
    final yaml = loadYaml(await pubspec.readAsString());
    if (yaml is! YamlMap || yaml['version'] is! String) {
      throw StateError('Release package has no version: ${pubspec.path}');
    }
    versions[packageName] = (yaml['version']! as String).trim();
  }
  return versions;
}

Future<List<File>> buildReleaseCandidateFragment({
  required String workspaceRoot,
  required VerificationExecutionId executionId,
  required String outputDirectory,
  required VerificationCommandRunner runCommand,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
}) async {
  final rows = buildIntegrationExecutionRows();
  final matchingRows = rows.where((row) => row.executionId == executionId);
  if (matchingRows.length != 1) {
    throw StateError('Unknown release fragment execution: $executionId');
  }
  final row = matchingRows.single;
  final absoluteWorkspace = Directory(workspaceRoot).absolute.path;
  final output = Directory(outputDirectory).absolute;
  await output.create(recursive: true);
  if (output.listSync(followLinks: false).isNotEmpty) {
    throw StateError('Release fragment output must be empty: ${output.path}');
  }
  await runGroupedNativeBuild(
    workspaceRoot: absoluteWorkspace,
    row: row,
    profile: 'release',
    outputDirectory: output.path,
    runCommand: runCommand,
    resolveBashExecutable: resolveBashExecutable,
  );

  final expected = row.targets
      .map((target) => target.releaseAssetFileName)
      .toSet();
  final entities = output.listSync(followLinks: false);
  final actual = <String>{
    for (final entity in entities)
      if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
          FileSystemEntityType.file)
        p.basename(entity.path),
  };
  final missing = expected.difference(actual).toList()..sort();
  final unknown = <String>{
    ...actual.difference(expected),
    for (final entity in entities)
      if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
          FileSystemEntityType.file)
        p.basename(entity.path),
  }.toList()..sort();
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw StateError(
      'Release fragment coverage mismatch for $executionId: '
      'missing=$missing unknown=$unknown',
    );
  }
  return List<File>.unmodifiable(<File>[
    for (final target in row.targets)
      File(p.join(output.path, target.releaseAssetFileName)).absolute,
  ]);
}

Future<ReleaseCandidateAssembly> assembleReleaseCandidate({
  required String candidateDirectory,
  required String version,
  required String repository,
}) async {
  final input = ReleaseTransactionInput.parse(
    version: version,
    commitSha: List<String>.filled(40, '0').join(),
  );
  final normalizedRepository = repository.trim();
  if (!RegExp(r'^[^/\s]+/[^/\s]+$').hasMatch(normalizedRepository)) {
    throw FormatException('Repository must use owner/name form: $repository');
  }
  final directory = Directory(candidateDirectory).absolute;
  validateCandidateArtifactCompleteness(directory);
  final manifest = File(
    p.join(directory.path, 'nexa_http_native_assets_manifest.json'),
  );
  final checksums = File(p.join(directory.path, 'SHA256SUMS'));
  if (manifest.existsSync() || checksums.existsSync()) {
    throw StateError(
      'Candidate metadata must be generated exactly once in ${directory.path}',
    );
  }
  final bundle = await writeNexaHttpNativeReleaseManifestBundle(
    distDirectory: directory.path,
    outputPath: manifest.path,
    shaOutputPath: checksums.path,
    baseUrl:
        'https://github.com/$normalizedRepository/releases/download/${input.tag}',
  );
  final assets = bundle.manifest['assets'];
  if (assets is! List<Object?>) {
    throw StateError('Generated release manifest has no assets');
  }
  final artifactDigests = <String, String>{
    for (final rawAsset in assets)
      if (rawAsset is Map<String, Object?> &&
          rawAsset['file_name'] is String &&
          rawAsset['sha256'] is String)
        rawAsset['file_name']! as String: rawAsset['sha256']! as String,
  };
  if (artifactDigests.length != nexaHttpSupportedNativeTargets.length) {
    throw StateError('Generated release manifest asset coverage mismatch');
  }
  return ReleaseCandidateAssembly(
    directory: directory,
    digest: candidateSetDigestFromArtifactDigests(artifactDigests),
    artifactDigests: Map<String, String>.unmodifiable(artifactDigests),
  );
}

Future<ValidatedReleasePublisherCandidate> validateReleasePublisherCandidate({
  required String workspaceRoot,
  required String repository,
  required ReleaseTransactionInput input,
  required String candidateDirectory,
  required String candidateId,
  required String candidateDigest,
  required ReleaseCommitResolver resolveCommit,
  required ReleaseCommitMembershipChecker isCommitOnMain,
  required ReleaseRemoteStateChecker tagExists,
  required ReleaseRemoteStateChecker releaseExists,
}) async {
  if (!RegExp(r'^gha:[1-9][0-9]*:[1-9][0-9]*$').hasMatch(candidateId)) {
    throw FormatException('Invalid GitHub Actions candidate ID: $candidateId');
  }
  final transaction = await validateReleaseTransaction(
    workspaceRoot: workspaceRoot,
    repository: repository,
    input: input,
    mode: ReleaseValidationMode.dispatch,
    resolveCommit: resolveCommit,
    isCommitOnMain: isCommitOnMain,
    tagExists: tagExists,
    releaseExists: releaseExists,
  );
  final candidate = await verifyCandidateSet(
    Directory(candidateDirectory),
    candidateId: candidateId,
    expectedDigest: candidateDigest,
    sdkRef: input.commitSha,
  );
  await _verifyReleaseManifestSourceUrls(
    candidate.candidateDirectory,
    transaction.manifestBaseUrl,
  );
  final manifestFile = File(
    p.join(
      candidate.candidateDirectory.path,
      'nexa_http_native_assets_manifest.json',
    ),
  );
  final checksumsFile = File(
    p.join(candidate.candidateDirectory.path, 'SHA256SUMS'),
  );
  final publicationFiles = <File>[
    for (final target in nexaHttpSupportedNativeTargets)
      candidate.artifactFiles[target.releaseAssetFileName]!,
    manifestFile,
    checksumsFile,
  ];
  final publicationDigests = <String, String>{
    ...candidate.artifactDigests,
    p.basename(manifestFile.path): await sha256OfFile(manifestFile),
    p.basename(checksumsFile.path): await sha256OfFile(checksumsFile),
  };
  return ValidatedReleasePublisherCandidate(
    transaction: transaction,
    candidate: candidate,
    publicationFiles: List<File>.unmodifiable(publicationFiles),
    publicationDigests: Map<String, String>.unmodifiable(publicationDigests),
  );
}

Future<ValidatedReleasePublisherCandidate> publishReleaseCandidate({
  required String workspaceRoot,
  required String repository,
  required ReleaseTransactionInput input,
  required String candidateDirectory,
  required String candidateId,
  required String candidateDigest,
  required ReleaseCommitResolver resolveCommit,
  required ReleaseCommitMembershipChecker isCommitOnMain,
  required ReleaseRemoteStateChecker tagExists,
  required ReleaseRemoteStateChecker releaseExists,
  required ReleasePublicationGateway publicationGateway,
}) async {
  final validated = await validateReleasePublisherCandidate(
    workspaceRoot: workspaceRoot,
    repository: repository,
    input: input,
    candidateDirectory: candidateDirectory,
    candidateId: candidateId,
    candidateDigest: candidateDigest,
    resolveCommit: resolveCommit,
    isCommitOnMain: isCommitOnMain,
    tagExists: tagExists,
    releaseExists: releaseExists,
  );
  final transactionMarker =
      'candidate=${validated.candidate.candidateId};'
      'digest=${validated.candidate.digest}';
  try {
    await publicationGateway.createTag(
      repository: repository,
      tag: input.tag,
      commitSha: input.commitSha,
      transactionMarker: transactionMarker,
    );
    await publicationGateway.createRelease(
      repository: repository,
      tag: input.tag,
      transactionMarker: transactionMarker,
    );
    await publicationGateway.uploadAssets(
      repository: repository,
      tag: input.tag,
      files: validated.publicationFiles,
    );
    final remoteDigests = await publicationGateway.fetchReleaseAssetDigests(
      repository: repository,
      tag: input.tag,
    );
    if (remoteDigests.length != validated.publicationDigests.length ||
        remoteDigests.entries.any(
          (entry) => validated.publicationDigests[entry.key] != entry.value,
        ) ||
        validated.publicationDigests.keys.any(
          (fileName) => !remoteDigests.containsKey(fileName),
        )) {
      throw StateError(
        'Published release asset digest mismatch: '
        'expected=${validated.publicationDigests} actual=$remoteDigests',
      );
    }
    return validated;
  } catch (error, stackTrace) {
    final cleanupErrors = await _cleanupReleaseTransactionState(
      repository: repository,
      input: input,
      transactionMarker: transactionMarker,
      publicationGateway: publicationGateway,
    );
    if (cleanupErrors.isNotEmpty) {
      Error.throwWithStackTrace(
        StateError(
          'Release publication failed: $error; '
          'transaction cleanup also failed: $cleanupErrors',
        ),
        stackTrace,
      );
    }
    rethrow;
  }
}

Future<List<Object>> _cleanupReleaseTransactionState({
  required String repository,
  required ReleaseTransactionInput input,
  required String transactionMarker,
  required ReleasePublicationGateway publicationGateway,
}) async {
  final cleanupErrors = <Object>[];
  var absenceConfirmed = false;
  for (var attempt = 1; attempt <= 3; attempt++) {
    cleanupErrors.clear();
    var releaseOwned = false;
    var tagOwned = false;
    try {
      releaseOwned = await publicationGateway.ownsRelease(
        repository: repository,
        tag: input.tag,
        transactionMarker: transactionMarker,
      );
      if (releaseOwned) {
        absenceConfirmed = false;
      }
    } catch (error) {
      absenceConfirmed = false;
      cleanupErrors.add(error);
    }
    try {
      tagOwned = await publicationGateway.ownsTag(
        repository: repository,
        tag: input.tag,
        commitSha: input.commitSha,
        transactionMarker: transactionMarker,
      );
      if (tagOwned) {
        absenceConfirmed = false;
      }
    } catch (error) {
      absenceConfirmed = false;
      cleanupErrors.add(error);
    }
    if (releaseOwned) {
      try {
        await publicationGateway.deleteRelease(
          repository: repository,
          tag: input.tag,
        );
      } catch (error) {
        absenceConfirmed = false;
        cleanupErrors.add(error);
      }
    }
    if (tagOwned) {
      try {
        await publicationGateway.deleteTag(
          repository: repository,
          tag: input.tag,
        );
      } catch (error) {
        absenceConfirmed = false;
        cleanupErrors.add(error);
      }
    }
    bool? releaseStillOwned;
    bool? tagStillOwned;
    try {
      releaseStillOwned = await publicationGateway.ownsRelease(
        repository: repository,
        tag: input.tag,
        transactionMarker: transactionMarker,
      );
      if (releaseStillOwned) {
        absenceConfirmed = false;
      }
    } catch (error) {
      absenceConfirmed = false;
      cleanupErrors.add(error);
    }
    try {
      tagStillOwned = await publicationGateway.ownsTag(
        repository: repository,
        tag: input.tag,
        commitSha: input.commitSha,
        transactionMarker: transactionMarker,
      );
      if (tagStillOwned) {
        absenceConfirmed = false;
      }
    } catch (error) {
      absenceConfirmed = false;
      cleanupErrors.add(error);
    }
    if (releaseStillOwned == false && tagStillOwned == false) {
      if (absenceConfirmed) {
        return const <Object>[];
      }
      absenceConfirmed = true;
    } else if (releaseStillOwned == true || tagStillOwned == true) {
      cleanupErrors.add(
        StateError(
          'Owned release state still exists after cleanup attempt $attempt',
        ),
      );
    }
    if (attempt < 3) {
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
  cleanupErrors.add(
    StateError('Unable to confirm stable absence of owned release state'),
  );
  return List<Object>.unmodifiable(cleanupErrors);
}

Future<void> _verifyReleaseManifestSourceUrls(
  Directory candidateDirectory,
  String manifestBaseUrl,
) async {
  final manifestFile = File(
    p.join(candidateDirectory.path, 'nexa_http_native_assets_manifest.json'),
  );
  final decoded = jsonDecode(await manifestFile.readAsString());
  if (decoded is! Map<String, Object?> || decoded['assets'] is! List<Object?>) {
    throw StateError('Invalid release candidate manifest structure');
  }
  for (final rawAsset in decoded['assets']! as List<Object?>) {
    if (rawAsset is! Map<String, Object?> ||
        rawAsset['file_name'] is! String ||
        rawAsset['source_url'] is! String) {
      throw StateError('Invalid release candidate manifest asset URL entry');
    }
    final fileName = rawAsset['file_name']! as String;
    final expectedUrl = '$manifestBaseUrl/$fileName';
    if (rawAsset['source_url'] != expectedUrl) {
      throw StateError(
        'Release candidate manifest URL mismatch for $fileName: '
        'expected=$expectedUrl actual=${rawAsset['source_url']}',
      );
    }
  }
}
