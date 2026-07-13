import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../scripts/release/release_transaction.dart';
import '../scripts/verification/command.dart';
import '../scripts/verification/model.dart';

void main() {
  group('release transaction input', () {
    test('normalizes a stable version and full commit sha', () {
      final input = ReleaseTransactionInput.parse(
        version: '2.0.0',
        commitSha: _repeat('A', 40),
      );

      expect(input.version, '2.0.0');
      expect(input.tag, 'v2.0.0');
      expect(input.commitSha, _repeat('a', 40));
    });

    test('rejects tag-shaped, prerelease, and abbreviated inputs', () {
      for (final version in <String>[
        'v2.0.0',
        '2.0.0-rc.1',
        '2.0',
        '01.0.0',
        '1.00.0',
        '1.0.00',
      ]) {
        expect(
          () => ReleaseTransactionInput.parse(
            version: version,
            commitSha: _repeat('a', 40),
          ),
          throwsA(isA<FormatException>()),
        );
      }
      expect(
        () => ReleaseTransactionInput.parse(
          version: '2.0.0',
          commitSha: 'abc1234',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-canonical whitespace before concurrency grouping', () {
      for (final input in <({String version, String commitSha})>[
        (version: ' 2.0.0', commitSha: _repeat('a', 40)),
        (version: '2.0.0 ', commitSha: _repeat('a', 40)),
        (version: '2.0.0', commitSha: ' ${_repeat('a', 40)}'),
        (version: '2.0.0', commitSha: '${_repeat('a', 40)} '),
      ]) {
        expect(
          () => ReleaseTransactionInput.parse(
            version: input.version,
            commitSha: input.commitSha,
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test(
      'validates all package versions and remote state before release',
      () async {
        final workspace = await _createWorkspaceVersions('2.0.0');
        addTearDown(() => workspace.delete(recursive: true));
        final input = ReleaseTransactionInput.parse(
          version: '2.0.0',
          commitSha: _repeat('b', 40),
        );

        final validated = await validateReleaseTransaction(
          workspaceRoot: workspace.path,
          repository: 'iamdennisme/nexa_http',
          input: input,
          mode: ReleaseValidationMode.dispatch,
          resolveCommit: (sha) async => sha,
          isCommitOnMain: (_) async => true,
          tagExists: (_) async => false,
          releaseExists: (_) async => false,
        );

        expect(
          validated.manifestBaseUrl,
          contains('/releases/download/v2.0.0'),
        );
        expect(validated.packageVersions.values.toSet(), <String>{'2.0.0'});
      },
    );

    test(
      'fails before build when metadata or remote state conflicts',
      () async {
        final workspace = await _createWorkspaceVersions(
          '2.0.0',
          overrides: const <String, String>{
            'nexa_http_native_windows': '2.0.1',
          },
        );
        addTearDown(() => workspace.delete(recursive: true));
        final input = ReleaseTransactionInput.parse(
          version: '2.0.0',
          commitSha: _repeat('c', 40),
        );

        await expectLater(
          validateReleaseTransaction(
            workspaceRoot: workspace.path,
            repository: 'iamdennisme/nexa_http',
            input: input,
            mode: ReleaseValidationMode.dispatch,
            resolveCommit: (sha) async => sha,
            isCommitOnMain: (_) async => true,
            tagExists: (_) async => false,
            releaseExists: (_) async => false,
          ),
          throwsA(isA<StateError>()),
        );

        await _writeWorkspaceVersions(workspace, '2.0.0');
        for (final conflict in <String>['commit', 'tag', 'release']) {
          await expectLater(
            validateReleaseTransaction(
              workspaceRoot: workspace.path,
              repository: 'iamdennisme/nexa_http',
              input: input,
              mode: ReleaseValidationMode.dispatch,
              resolveCommit: (sha) async => sha,
              isCommitOnMain: (_) async => conflict != 'commit',
              tagExists: (_) async => conflict == 'tag',
              releaseExists: (_) async => conflict == 'release',
            ),
            throwsA(isA<StateError>()),
          );
        }
      },
    );

    test('pull request rehearsal accepts its exact unmerged head', () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      addTearDown(() => workspace.delete(recursive: true));
      final input = ReleaseTransactionInput.parse(
        version: '2.0.0',
        commitSha: _repeat('d', 40),
      );

      final validated = await validateReleaseTransaction(
        workspaceRoot: workspace.path,
        repository: 'iamdennisme/nexa_http',
        input: input,
        mode: ReleaseValidationMode.pullRequest,
        resolveCommit: (sha) async => sha,
        resolveCheckoutHead: () async => input.commitSha,
        isCommitOnMain: (_) async => false,
        tagExists: (_) async => false,
        releaseExists: (_) async => false,
      );

      expect(validated.input.commitSha, _repeat('d', 40));
    });

    test('pull request rehearsal rejects checkout head drift', () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      addTearDown(() => workspace.delete(recursive: true));
      final input = ReleaseTransactionInput.parse(
        version: '2.0.0',
        commitSha: _repeat('d', 40),
      );

      await expectLater(
        validateReleaseTransaction(
          workspaceRoot: workspace.path,
          repository: 'iamdennisme/nexa_http',
          input: input,
          mode: ReleaseValidationMode.pullRequest,
          resolveCommit: (sha) async => sha,
          resolveCheckoutHead: () async => _repeat('e', 40),
          isCommitOnMain: (_) async => false,
          tagExists: (_) async => false,
          releaseExists: (_) async => false,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('release candidate fragment', () {
    test('builds every Android target in one release invocation', () async {
      final root = await Directory.systemTemp.createTemp(
        'nexa_release_fragment_',
      );
      addTearDown(() => root.delete(recursive: true));
      final commands = <VerificationCommand>[];

      final files = await buildReleaseCandidateFragment(
        workspaceRoot: root.path,
        executionId: const VerificationExecutionId('android-linux'),
        outputDirectory: p.join(root.path, 'fragment'),
        runCommand: (command) async {
          commands.add(command);
          await _materializeRequestedTargets(command);
        },
        resolveBashExecutable: () async => '/bin/bash',
      );

      expect(commands, hasLength(1));
      expect(commands.single.arguments, contains('release'));
      expect(
        commands.single.arguments.where((value) => value == '--target'),
        hasLength(3),
      );
      expect(files, hasLength(3));
    });

    test(
      'builds Apple with one invocation per canonical build script',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'nexa_release_fragment_',
        );
        addTearDown(() => root.delete(recursive: true));
        final commands = <VerificationCommand>[];

        final files = await buildReleaseCandidateFragment(
          workspaceRoot: root.path,
          executionId: const VerificationExecutionId('apple-macos'),
          outputDirectory: p.join(root.path, 'fragment'),
          runCommand: (command) async {
            commands.add(command);
            await _materializeRequestedTargets(command);
          },
          resolveBashExecutable: () async => '/bin/bash',
        );

        expect(commands, hasLength(2));
        expect(files, hasLength(5));
      },
    );

    test('rejects unknown or extra fragment files', () async {
      final root = await Directory.systemTemp.createTemp(
        'nexa_release_fragment_',
      );
      addTearDown(() => root.delete(recursive: true));
      await expectLater(
        buildReleaseCandidateFragment(
          workspaceRoot: root.path,
          executionId: const VerificationExecutionId('unknown'),
          outputDirectory: p.join(root.path, 'unknown'),
          runCommand: (_) async {},
          resolveBashExecutable: () async => '/bin/bash',
        ),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        buildReleaseCandidateFragment(
          workspaceRoot: root.path,
          executionId: const VerificationExecutionId('windows-x64'),
          outputDirectory: p.join(root.path, 'windows'),
          runCommand: (command) async {
            await _materializeRequestedTargets(command);
            await File(
              p.join(root.path, 'windows', 'unexpected.dll'),
            ).writeAsString('unexpected');
          },
          resolveBashExecutable: () async => '/bin/bash',
        ),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        buildReleaseCandidateFragment(
          workspaceRoot: root.path,
          executionId: const VerificationExecutionId('windows-x64'),
          outputDirectory: p.join(root.path, 'windows-with-directory'),
          runCommand: (command) async {
            await _materializeRequestedTargets(command);
            await Directory(
              p.join(root.path, 'windows-with-directory', 'nested'),
            ).create();
          },
          resolveBashExecutable: () async => '/bin/bash',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('release candidate assembly', () {
    test(
      'generates manifest and checksums once in the merged directory',
      () async {
        final candidate = await _createCandidateAssets();
        addTearDown(() => candidate.delete(recursive: true));

        final assembled = await assembleReleaseCandidate(
          candidateDirectory: candidate.path,
          version: '2.0.0',
          repository: 'iamdennisme/nexa_http',
        );

        expect(assembled.artifactDigests, hasLength(9));
        expect(assembled.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(
          File(
            p.join(candidate.path, 'nexa_http_native_assets_manifest.json'),
          ).readAsStringSync(),
          contains('/releases/download/v2.0.0/'),
        );
        expect(File(p.join(candidate.path, 'SHA256SUMS')).existsSync(), isTrue);
      },
    );

    test('digest changes when a canonical candidate byte changes', () async {
      final first = await _createCandidateAssets();
      final second = await _createCandidateAssets();
      addTearDown(() => first.delete(recursive: true));
      addTearDown(() => second.delete(recursive: true));

      final firstAssembly = await assembleReleaseCandidate(
        candidateDirectory: first.path,
        version: '2.0.0',
        repository: 'iamdennisme/nexa_http',
      );
      final changed = nexaHttpSupportedNativeTargets.first.releaseAssetFileName;
      await File(p.join(second.path, changed)).writeAsString('changed');
      final secondAssembly = await assembleReleaseCandidate(
        candidateDirectory: second.path,
        version: '2.0.0',
        repository: 'iamdennisme/nexa_http',
      );

      expect(secondAssembly.digest, isNot(firstAssembly.digest));
    });

    test('rejects pre-generated metadata or incomplete assets', () async {
      final candidate = await _createCandidateAssets();
      addTearDown(() => candidate.delete(recursive: true));
      await File(p.join(candidate.path, 'SHA256SUMS')).writeAsString('stale');
      await expectLater(
        assembleReleaseCandidate(
          candidateDirectory: candidate.path,
          version: '2.0.0',
          repository: 'iamdennisme/nexa_http',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('release publisher preflight', () {
    test('rejects a candidate manifest URL that was not gated', () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      final candidate = await _createCandidateAssets();
      addTearDown(() => workspace.delete(recursive: true));
      addTearDown(() => candidate.delete(recursive: true));
      final assembly = await assembleReleaseCandidate(
        candidateDirectory: candidate.path,
        version: '2.0.0',
        repository: 'iamdennisme/nexa_http',
      );
      final manifestFile = File(
        p.join(candidate.path, 'nexa_http_native_assets_manifest.json'),
      );
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
      final assets = manifest['assets']! as List<Object?>;
      (assets.first! as Map<String, Object?>)['source_url'] =
          'https://example.invalid/unverified-native-asset';
      await manifestFile.writeAsString(jsonEncode(manifest));
      final input = ReleaseTransactionInput.parse(
        version: '2.0.0',
        commitSha: _repeat('e', 40),
      );

      await expectLater(
        validateReleasePublisherCandidate(
          workspaceRoot: workspace.path,
          repository: 'iamdennisme/nexa_http',
          input: input,
          candidateDirectory: candidate.path,
          candidateId: 'gha:42:314',
          candidateDigest: assembly.digest,
          resolveCommit: (sha) async => sha,
          isCommitOnMain: (_) async => true,
          tagExists: (_) async => false,
          releaseExists: (_) async => false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'publishes the exact candidate files with their original names',
      () async {
        final workspace = await _createWorkspaceVersions('2.0.0');
        final candidate = await _createCandidateAssets();
        addTearDown(() => workspace.delete(recursive: true));
        addTearDown(() => candidate.delete(recursive: true));
        final assembly = await assembleReleaseCandidate(
          candidateDirectory: candidate.path,
          version: '2.0.0',
          repository: 'iamdennisme/nexa_http',
        );
        final expectedDigests = <String, String>{};
        for (final entity in candidate.listSync().whereType<File>()) {
          expectedDigests[p.basename(entity.path)] = await sha256OfFile(entity);
        }
        final gateway = _RecordingReleasePublicationGateway(expectedDigests);
        final input = ReleaseTransactionInput.parse(
          version: '2.0.0',
          commitSha: _repeat('f', 40),
        );

        await publishReleaseCandidate(
          workspaceRoot: workspace.path,
          repository: 'iamdennisme/nexa_http',
          input: input,
          candidateDirectory: candidate.path,
          candidateId: 'gha:42:314',
          candidateDigest: assembly.digest,
          resolveCommit: (sha) async => sha,
          isCommitOnMain: (_) async => true,
          tagExists: (_) async => false,
          releaseExists: (_) async => false,
          publicationGateway: gateway,
        );

        expect(gateway.createdTags, <String>['v2.0.0']);
        expect(gateway.uploadedFileNames.toSet(), expectedDigests.keys.toSet());
        expect(gateway.deletedReleases, isEmpty);
        expect(gateway.deletedTags, isEmpty);
      },
    );

    test(
      'removes only the created release and tag when digest proof fails',
      () async {
        final workspace = await _createWorkspaceVersions('2.0.0');
        final candidate = await _createCandidateAssets();
        addTearDown(() => workspace.delete(recursive: true));
        addTearDown(() => candidate.delete(recursive: true));
        final assembly = await assembleReleaseCandidate(
          candidateDirectory: candidate.path,
          version: '2.0.0',
          repository: 'iamdennisme/nexa_http',
        );
        final gateway = _RecordingReleasePublicationGateway(
          const <String, String>{},
        );
        final input = ReleaseTransactionInput.parse(
          version: '2.0.0',
          commitSha: _repeat('f', 40),
        );

        await expectLater(
          publishReleaseCandidate(
            workspaceRoot: workspace.path,
            repository: 'iamdennisme/nexa_http',
            input: input,
            candidateDirectory: candidate.path,
            candidateId: 'gha:42:314',
            candidateDigest: assembly.digest,
            resolveCommit: (sha) async => sha,
            isCommitOnMain: (_) async => true,
            tagExists: (_) async => false,
            releaseExists: (_) async => false,
            publicationGateway: gateway,
          ),
          throwsA(isA<StateError>()),
        );

        expect(gateway.deletedReleases, <String>['v2.0.0']);
        expect(gateway.deletedTags, <String>['v2.0.0']);
      },
    );

    test('release creation failure compensates only the owned tag', () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      final candidate = await _createCandidateAssets();
      addTearDown(() => workspace.delete(recursive: true));
      addTearDown(() => candidate.delete(recursive: true));
      final assembly = await assembleReleaseCandidate(
        candidateDirectory: candidate.path,
        version: '2.0.0',
        repository: 'iamdennisme/nexa_http',
      );
      final gateway = _RecordingReleasePublicationGateway(
        const <String, String>{},
        failAfterTagCreation: true,
      );

      await expectLater(
        publishReleaseCandidate(
          workspaceRoot: workspace.path,
          repository: 'iamdennisme/nexa_http',
          input: ReleaseTransactionInput.parse(
            version: '2.0.0',
            commitSha: _repeat('f', 40),
          ),
          candidateDirectory: candidate.path,
          candidateId: 'gha:42:314',
          candidateDigest: assembly.digest,
          resolveCommit: (sha) async => sha,
          isCommitOnMain: (_) async => true,
          tagExists: (_) async => false,
          releaseExists: (_) async => false,
          publicationGateway: gateway,
        ),
        throwsA(isA<StateError>()),
      );

      expect(gateway.deletedReleases, isEmpty);
      expect(gateway.deletedTags, <String>['v2.0.0']);
    });

    test(
      'uncertain release response discovers and removes owned state',
      () async {
        final workspace = await _createWorkspaceVersions('2.0.0');
        final candidate = await _createCandidateAssets();
        addTearDown(() => workspace.delete(recursive: true));
        addTearDown(() => candidate.delete(recursive: true));
        final assembly = await assembleReleaseCandidate(
          candidateDirectory: candidate.path,
          version: '2.0.0',
          repository: 'iamdennisme/nexa_http',
        );
        final gateway = _RecordingReleasePublicationGateway(
          const <String, String>{},
          failAfterReleaseCreation: true,
        );

        await expectLater(
          publishReleaseCandidate(
            workspaceRoot: workspace.path,
            repository: 'iamdennisme/nexa_http',
            input: ReleaseTransactionInput.parse(
              version: '2.0.0',
              commitSha: _repeat('f', 40),
            ),
            candidateDirectory: candidate.path,
            candidateId: 'gha:42:314',
            candidateDigest: assembly.digest,
            resolveCommit: (sha) async => sha,
            isCommitOnMain: (_) async => true,
            tagExists: (_) async => false,
            releaseExists: (_) async => false,
            publicationGateway: gateway,
          ),
          throwsA(isA<StateError>()),
        );

        expect(gateway.deletedReleases, <String>['v2.0.0']);
        expect(gateway.deletedTags, <String>['v2.0.0']);
      },
    );
  });
}

final class _RecordingReleasePublicationGateway
    implements ReleasePublicationGateway {
  _RecordingReleasePublicationGateway(
    this.remoteDigests, {
    this.failAfterTagCreation = false,
    this.failAfterReleaseCreation = false,
  });

  final Map<String, String> remoteDigests;
  final bool failAfterTagCreation;
  final bool failAfterReleaseCreation;
  bool tagOwned = false;
  bool releaseOwned = false;
  final List<String> createdTags = <String>[];
  final List<String> uploadedFileNames = <String>[];
  final List<String> deletedReleases = <String>[];
  final List<String> deletedTags = <String>[];

  @override
  Future<void> createTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  }) async {
    createdTags.add(tag);
    tagOwned = true;
  }

  @override
  Future<void> createRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  }) async {
    if (failAfterTagCreation) {
      throw StateError('release creation failed after tag creation');
    }
    releaseOwned = true;
    if (failAfterReleaseCreation) {
      throw StateError('release response failed after creation');
    }
  }

  @override
  Future<void> deleteRelease({
    required String repository,
    required String tag,
  }) async {
    deletedReleases.add(tag);
    releaseOwned = false;
  }

  @override
  Future<void> deleteTag({
    required String repository,
    required String tag,
  }) async {
    deletedTags.add(tag);
    tagOwned = false;
  }

  @override
  Future<Map<String, String>> fetchReleaseAssetDigests({
    required String repository,
    required String tag,
  }) async => remoteDigests;

  @override
  Future<bool> ownsRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  }) async => releaseOwned;

  @override
  Future<bool> ownsTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  }) async => tagOwned;

  @override
  Future<void> uploadAssets({
    required String repository,
    required String tag,
    required List<File> files,
  }) async {
    uploadedFileNames.addAll(files.map((file) => p.basename(file.path)));
  }
}

const _packageNames = <String>[
  'nexa_http',
  'nexa_http_native_internal',
  'nexa_http_native_android',
  'nexa_http_native_ios',
  'nexa_http_native_macos',
  'nexa_http_native_windows',
];

Future<Directory> _createWorkspaceVersions(
  String version, {
  Map<String, String> overrides = const <String, String>{},
}) async {
  final root = await Directory.systemTemp.createTemp('nexa_release_input_');
  await _writeWorkspaceVersions(root, version, overrides: overrides);
  return root;
}

Future<void> _writeWorkspaceVersions(
  Directory root,
  String version, {
  Map<String, String> overrides = const <String, String>{},
}) async {
  for (final packageName in _packageNames) {
    final packageDirectory = Directory(
      p.join(root.path, 'packages', packageName),
    );
    await packageDirectory.create(recursive: true);
    await File(p.join(packageDirectory.path, 'pubspec.yaml')).writeAsString(
      'name: $packageName\nversion: ${overrides[packageName] ?? version}\n',
    );
  }
}

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

Future<void> _materializeRequestedTargets(VerificationCommand command) async {
  final outputIndex = command.arguments.indexOf('--output-dir');
  final output = Directory(command.arguments[outputIndex + 1]);
  await output.create(recursive: true);
  final requested = <String>[
    for (var index = 0; index < command.arguments.length; index++)
      if (command.arguments[index] == '--target') command.arguments[index + 1],
  ];
  for (final target in nexaHttpSupportedNativeTargets.where(
    (target) => requested.contains(target.rustTargetTriple),
  )) {
    await File(
      p.join(output.path, target.releaseAssetFileName),
    ).writeAsString(target.rustTargetTriple);
  }
}

Future<Directory> _createCandidateAssets() async {
  final directory = await Directory.systemTemp.createTemp('nexa_candidate_');
  for (final target in nexaHttpSupportedNativeTargets) {
    await File(
      p.join(directory.path, target.releaseAssetFileName),
    ).writeAsString('artifact:${target.releaseAssetFileName}');
  }
  return directory;
}
