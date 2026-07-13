import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../verification/command.dart';
import '../verification/model.dart';
import 'release_publication_gateway.dart';
import 'release_transaction.dart';

typedef ReleaseCliWriter = void Function(String value);

final class ReleaseTransactionCliUsageError implements Exception {
  const ReleaseTransactionCliUsageError(this.message);

  final String message;

  @override
  String toString() => message;
}

final class _ReleaseValidationDependencies {
  const _ReleaseValidationDependencies({
    required this.resolveCommit,
    required this.resolveCheckoutHead,
    required this.isCommitOnMain,
    required this.tagExists,
    required this.releaseExists,
  });

  final ReleaseCommitResolver resolveCommit;
  final ReleaseCheckoutHeadResolver resolveCheckoutHead;
  final ReleaseCommitMembershipChecker isCommitOnMain;
  final ReleaseRemoteStateChecker tagExists;
  final ReleaseRemoteStateChecker releaseExists;
}

final class _PublisherCliInput {
  const _PublisherCliInput({
    required this.workspaceRoot,
    required this.repository,
    required this.input,
    required this.candidateDirectory,
    required this.candidateId,
    required this.candidateDigest,
  });

  final String workspaceRoot;
  final String repository;
  final ReleaseTransactionInput input;
  final String candidateDirectory;
  final String candidateId;
  final String candidateDigest;
}

Future<int> runReleaseTransactionCli(
  List<String> arguments, {
  ReleaseCommitResolver? resolveCommit,
  ReleaseCheckoutHeadResolver? resolveCheckoutHead,
  ReleaseCommitMembershipChecker? isCommitOnMain,
  ReleaseRemoteStateChecker? tagExists,
  ReleaseRemoteStateChecker? releaseExists,
  VerificationCommandRunner? runCommand,
  ReleasePublicationGateway? publicationGateway,
  ReleaseCliWriter? writeStdout,
  ReleaseCliWriter? writeStderr,
}) async {
  final stdoutWriter = writeStdout ?? stdout.writeln;
  final stderrWriter = writeStderr ?? stderr.writeln;
  if (arguments.isEmpty) {
    throw const ReleaseTransactionCliUsageError(
      'Release transaction command is required',
    );
  }
  switch (arguments.first) {
    case 'validate':
      final values = _parseOptions(arguments.skip(1).toList(growable: false));
      _rejectUnknownOptions(values, const <String>{
        '--mode',
        '--workspace-root',
        '--repository',
        '--version',
        '--commit-sha',
      });
      final mode = switch (values['--mode']) {
        'pull-request' => ReleaseValidationMode.pullRequest,
        'dispatch' => ReleaseValidationMode.dispatch,
        final value => throw ReleaseTransactionCliUsageError(
          'Invalid release validation mode: $value',
        ),
      };
      final workspaceRoot = _requiredOption(values, '--workspace-root');
      final repository = _requiredOption(values, '--repository');
      final commitSha = _requiredOption(values, '--commit-sha');
      final version = switch (mode) {
        ReleaseValidationMode.pullRequest => await _derivePackageVersion(
          workspaceRoot,
        ),
        ReleaseValidationMode.dispatch => _requiredOption(values, '--version'),
      };
      if (mode == ReleaseValidationMode.pullRequest &&
          values.containsKey('--version')) {
        throw const ReleaseTransactionCliUsageError(
          'pull-request validation derives version from package metadata',
        );
      }
      final input = ReleaseTransactionInput.parse(
        version: version,
        commitSha: commitSha,
      );
      final dependencies = _validationDependencies(
        workspaceRoot: workspaceRoot,
        repository: repository,
        resolveCommit: resolveCommit,
        resolveCheckoutHead: resolveCheckoutHead,
        isCommitOnMain: isCommitOnMain,
        tagExists: tagExists,
        releaseExists: releaseExists,
      );
      final validated = await validateReleaseTransaction(
        workspaceRoot: workspaceRoot,
        repository: repository,
        input: input,
        mode: mode,
        resolveCommit: dependencies.resolveCommit,
        resolveCheckoutHead: dependencies.resolveCheckoutHead,
        isCommitOnMain: dependencies.isCommitOnMain,
        tagExists: dependencies.tagExists,
        releaseExists: dependencies.releaseExists,
      );
      stdoutWriter(
        jsonEncode(<String, Object?>{
          'version': validated.input.version,
          'tag': validated.input.tag,
          'commit_sha': validated.input.commitSha,
          'repository': validated.repository,
          'manifest_base_url': validated.manifestBaseUrl,
        }),
      );
      return 0;
    case 'build-fragment':
      final values = _parseOptions(arguments.skip(1).toList(growable: false));
      _rejectUnknownOptions(values, const <String>{
        '--workspace-root',
        '--execution',
        '--output-dir',
      });
      final executionId = VerificationExecutionId(
        _requiredOption(values, '--execution'),
      );
      final files = await buildReleaseCandidateFragment(
        workspaceRoot: _requiredOption(values, '--workspace-root'),
        executionId: executionId,
        outputDirectory: _requiredOption(values, '--output-dir'),
        runCommand: runCommand ?? runVerificationCommand,
      );
      stdoutWriter(
        jsonEncode(<String, Object?>{
          'execution_id': executionId.value,
          'files': files
              .map((file) => p.basename(file.path))
              .toList(growable: false),
        }),
      );
      return 0;
    case 'assemble':
      final values = _parseOptions(arguments.skip(1).toList(growable: false));
      _rejectUnknownOptions(values, const <String>{
        '--candidate-dir',
        '--version',
        '--repository',
      });
      final assembled = await assembleReleaseCandidate(
        candidateDirectory: _requiredOption(values, '--candidate-dir'),
        version: _requiredOption(values, '--version'),
        repository: _requiredOption(values, '--repository'),
      );
      stdoutWriter(
        jsonEncode(<String, Object?>{
          'candidate_directory': assembled.directory.path,
          'candidate_digest': assembled.digest,
          'artifact_digests': assembled.artifactDigests,
        }),
      );
      return 0;
    case 'verify-publisher':
      final values = _parseOptions(arguments.skip(1).toList(growable: false));
      _rejectUnknownOptions(values, _publisherOptions);
      final publisherInput = _parsePublisherInput(values);
      final dependencies = _validationDependencies(
        workspaceRoot: publisherInput.workspaceRoot,
        repository: publisherInput.repository,
        resolveCommit: resolveCommit,
        resolveCheckoutHead: resolveCheckoutHead,
        isCommitOnMain: isCommitOnMain,
        tagExists: tagExists,
        releaseExists: releaseExists,
      );
      final validated = await validateReleasePublisherCandidate(
        workspaceRoot: publisherInput.workspaceRoot,
        repository: publisherInput.repository,
        input: publisherInput.input,
        candidateDirectory: publisherInput.candidateDirectory,
        candidateId: publisherInput.candidateId,
        candidateDigest: publisherInput.candidateDigest,
        resolveCommit: dependencies.resolveCommit,
        isCommitOnMain: dependencies.isCommitOnMain,
        tagExists: dependencies.tagExists,
        releaseExists: dependencies.releaseExists,
      );
      stdoutWriter(
        jsonEncode(<String, Object?>{
          'version': validated.transaction.input.version,
          'tag': validated.transaction.input.tag,
          'commit_sha': validated.transaction.input.commitSha,
          'candidate_id': validated.candidate.candidateId,
          'candidate_digest': validated.candidate.digest,
        }),
      );
      return 0;
    case 'publish':
      final values = _parseOptions(arguments.skip(1).toList(growable: false));
      _rejectUnknownOptions(values, _publisherOptions);
      final publisherInput = _parsePublisherInput(values);
      final dependencies = _validationDependencies(
        workspaceRoot: publisherInput.workspaceRoot,
        repository: publisherInput.repository,
        resolveCommit: resolveCommit,
        resolveCheckoutHead: resolveCheckoutHead,
        isCommitOnMain: isCommitOnMain,
        tagExists: tagExists,
        releaseExists: releaseExists,
      );
      final published = await publishReleaseCandidate(
        workspaceRoot: publisherInput.workspaceRoot,
        repository: publisherInput.repository,
        input: publisherInput.input,
        candidateDirectory: publisherInput.candidateDirectory,
        candidateId: publisherInput.candidateId,
        candidateDigest: publisherInput.candidateDigest,
        resolveCommit: dependencies.resolveCommit,
        isCommitOnMain: dependencies.isCommitOnMain,
        tagExists: dependencies.tagExists,
        releaseExists: dependencies.releaseExists,
        publicationGateway: publicationGateway ?? GhReleasePublicationGateway(),
      );
      stdoutWriter(
        jsonEncode(<String, Object?>{
          'published': true,
          'version': published.transaction.input.version,
          'tag': published.transaction.input.tag,
          'commit_sha': published.transaction.input.commitSha,
          'candidate_id': published.candidate.candidateId,
          'candidate_digest': published.candidate.digest,
        }),
      );
      return 0;
    default:
      stderrWriter('Unknown release transaction command: ${arguments.first}');
      throw ReleaseTransactionCliUsageError(
        'Unknown release transaction command: ${arguments.first}',
      );
  }
}

const _publisherOptions = <String>{
  '--workspace-root',
  '--repository',
  '--version',
  '--commit-sha',
  '--candidate-dir',
  '--candidate-id',
  '--candidate-digest',
};

_PublisherCliInput _parsePublisherInput(Map<String, String> values) {
  return _PublisherCliInput(
    workspaceRoot: _requiredOption(values, '--workspace-root'),
    repository: _requiredOption(values, '--repository'),
    input: ReleaseTransactionInput.parse(
      version: _requiredOption(values, '--version'),
      commitSha: _requiredOption(values, '--commit-sha'),
    ),
    candidateDirectory: _requiredOption(values, '--candidate-dir'),
    candidateId: _requiredOption(values, '--candidate-id'),
    candidateDigest: _requiredOption(values, '--candidate-digest'),
  );
}

_ReleaseValidationDependencies _validationDependencies({
  required String workspaceRoot,
  required String repository,
  required ReleaseCommitResolver? resolveCommit,
  required ReleaseCheckoutHeadResolver? resolveCheckoutHead,
  required ReleaseCommitMembershipChecker? isCommitOnMain,
  required ReleaseRemoteStateChecker? tagExists,
  required ReleaseRemoteStateChecker? releaseExists,
}) {
  return _ReleaseValidationDependencies(
    resolveCommit: resolveCommit ?? (sha) => _resolveCommit(workspaceRoot, sha),
    resolveCheckoutHead:
        resolveCheckoutHead ?? () => _resolveCheckoutHead(workspaceRoot),
    isCommitOnMain:
        isCommitOnMain ??
        (sha) => _isCommitReachableFromMain(workspaceRoot, sha),
    tagExists:
        tagExists ??
        (tag) => _githubResourceExists(
          repository,
          'git/ref/tags/${Uri.encodeComponent(tag)}',
        ),
    releaseExists:
        releaseExists ??
        (tag) => _githubResourceExists(
          repository,
          'releases/tags/${Uri.encodeComponent(tag)}',
        ),
  );
}

Map<String, String> _parseOptions(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw ReleaseTransactionCliUsageError(
      'Missing value for release option ${arguments.last}',
    );
  }
  final values = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final option = arguments[index];
    final value = arguments[index + 1];
    if (!option.startsWith('--') || value.trim().isEmpty) {
      throw ReleaseTransactionCliUsageError('Invalid release option: $option');
    }
    if (value != value.trim()) {
      throw ReleaseTransactionCliUsageError(
        'Release option must not contain surrounding whitespace: $option',
      );
    }
    if (values.containsKey(option)) {
      throw ReleaseTransactionCliUsageError(
        'Duplicate release option: $option',
      );
    }
    values[option] = value;
  }
  return values;
}

void _rejectUnknownOptions(Map<String, String> values, Set<String> supported) {
  final unknown = values.keys.where((option) => !supported.contains(option));
  if (unknown.isNotEmpty) {
    throw ReleaseTransactionCliUsageError(
      'Unknown release option: ${unknown.first}',
    );
  }
}

String _requiredOption(Map<String, String> values, String option) {
  final value = values[option];
  if (value == null) {
    throw ReleaseTransactionCliUsageError(
      'Missing required release option: $option',
    );
  }
  return value;
}

Future<String> _derivePackageVersion(String workspaceRoot) async {
  final versions = await readNexaHttpPackageVersions(workspaceRoot);
  final distinctVersions = versions.values.toSet();
  if (distinctVersions.length != 1) {
    throw StateError('Release package versions are inconsistent: $versions');
  }
  return distinctVersions.single;
}

Future<String> _resolveCommit(String workspaceRoot, String commitSha) async {
  final result = await Process.run('git', <String>[
    'rev-parse',
    '--verify',
    '$commitSha^{commit}',
  ], workingDirectory: workspaceRoot);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      <String>['rev-parse', '--verify', '$commitSha^{commit}'],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return (result.stdout as String).trim();
}

Future<String> _resolveCheckoutHead(String workspaceRoot) async {
  return _resolveCommit(workspaceRoot, 'HEAD');
}

Future<bool> _isCommitReachableFromMain(
  String workspaceRoot,
  String commitSha,
) async {
  final arguments = <String>[
    'merge-base',
    '--is-ancestor',
    commitSha,
    'origin/main',
  ];
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workspaceRoot,
  );
  if (result.exitCode == 0) {
    return true;
  }
  if (result.exitCode == 1) {
    return false;
  }
  throw ProcessException(
    'git',
    arguments,
    '${result.stdout}${result.stderr}',
    result.exitCode,
  );
}

Future<bool> _githubResourceExists(String repository, String path) async {
  final arguments = <String>['api', 'repos/$repository/$path', '--silent'];
  final result = await Process.run('gh', arguments);
  if (result.exitCode == 0) {
    return true;
  }
  final diagnostics = '${result.stdout}${result.stderr}';
  if (diagnostics.contains('HTTP 404') || diagnostics.contains('Not Found')) {
    return false;
  }
  throw ProcessException('gh', arguments, diagnostics, result.exitCode);
}
