import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/release/release_transaction.dart';
import '../scripts/release/release_transaction_cli.dart';
import '../scripts/verification/command.dart';

void main() {
  test(
    'validate derives PR version and emits normalized transaction JSON',
    () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      addTearDown(() => workspace.delete(recursive: true));
      final stdoutLines = <String>[];
      final commitSha = List<String>.filled(40, 'D').join();

      final exitCode = await runReleaseTransactionCli(
        <String>[
          'validate',
          '--mode',
          'pull-request',
          '--workspace-root',
          workspace.path,
          '--repository',
          'iamdennisme/nexa_http',
          '--commit-sha',
          commitSha,
        ],
        resolveCommit: (sha) async => sha,
        resolveCheckoutHead: () async => commitSha,
        isCommitOnMain: (_) async => false,
        tagExists: (_) async => false,
        releaseExists: (_) async => false,
        writeStdout: stdoutLines.add,
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines, hasLength(1));
      expect(jsonDecode(stdoutLines.single), <String, Object?>{
        'version': '2.0.0',
        'tag': 'v2.0.0',
        'commit_sha': commitSha.toLowerCase(),
        'repository': 'iamdennisme/nexa_http',
        'manifest_base_url':
            'https://github.com/iamdennisme/nexa_http/'
            'releases/download/v2.0.0',
      });
    },
  );

  test('validate rejects undeclared compatibility options', () async {
    final workspace = await _createWorkspaceVersions('2.0.0');
    addTearDown(() => workspace.delete(recursive: true));

    await expectLater(
      runReleaseTransactionCli(
        <String>[
          'validate',
          '--mode',
          'pull-request',
          '--workspace-root',
          workspace.path,
          '--repository',
          'iamdennisme/nexa_http',
          '--commit-sha',
          List<String>.filled(40, 'd').join(),
          '--legacy-tag-fallback',
          'true',
        ],
        resolveCommit: (sha) async => sha,
        isCommitOnMain: (_) async => false,
        tagExists: (_) async => false,
        releaseExists: (_) async => false,
        writeStdout: (_) {},
        writeStderr: (_) {},
      ),
      throwsA(isA<ReleaseTransactionCliUsageError>()),
    );
  });

  test(
    'dispatch rejects surrounding whitespace before normalization',
    () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      addTearDown(() => workspace.delete(recursive: true));

      await expectLater(
        runReleaseTransactionCli(
          <String>[
            'validate',
            '--mode',
            'dispatch',
            '--workspace-root',
            workspace.path,
            '--repository',
            'iamdennisme/nexa_http',
            '--version',
            ' 2.0.0',
            '--commit-sha',
            List<String>.filled(40, 'a').join(),
          ],
          resolveCommit: (sha) async => sha,
          isCommitOnMain: (_) async => true,
          tagExists: (_) async => false,
          releaseExists: (_) async => false,
          writeStdout: (_) {},
          writeStderr: (_) {},
        ),
        throwsA(isA<ReleaseTransactionCliUsageError>()),
      );
    },
  );

  test(
    'build-fragment projects one canonical execution into its output',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'nexa_release_cli_fragment_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final output = p.join(workspace.path, 'fragment');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseTransactionCli(
        <String>[
          'build-fragment',
          '--workspace-root',
          workspace.path,
          '--execution',
          'android-linux',
          '--output-dir',
          output,
        ],
        runCommand: (command) async => _materializeRequestedTargets(command),
        writeStdout: stdoutLines.add,
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      final json = jsonDecode(stdoutLines.single) as Map<String, Object?>;
      expect(json['execution_id'], 'android-linux');
      expect((json['files']! as List<Object?>), hasLength(3));
    },
  );

  test(
    'assemble generates metadata in place and emits candidate digest',
    () async {
      final candidate = await Directory.systemTemp.createTemp(
        'nexa_release_cli_candidate_',
      );
      addTearDown(() => candidate.delete(recursive: true));
      for (final target in nexaHttpSupportedNativeTargets) {
        await File(
          p.join(candidate.path, target.releaseAssetFileName),
        ).writeAsString(target.rustTargetTriple);
      }
      final stdoutLines = <String>[];

      final exitCode = await runReleaseTransactionCli(
        <String>[
          'assemble',
          '--candidate-dir',
          candidate.path,
          '--version',
          '2.0.0',
          '--repository',
          'iamdennisme/nexa_http',
        ],
        writeStdout: stdoutLines.add,
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      final json = jsonDecode(stdoutLines.single) as Map<String, Object?>;
      expect(json['candidate_directory'], candidate.absolute.path);
      expect(json['candidate_digest'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(File(p.join(candidate.path, 'SHA256SUMS')).existsSync(), isTrue);
    },
  );

  test(
    'verify-publisher revalidates the approved candidate without mutation',
    () async {
      final workspace = await _createWorkspaceVersions('2.0.0');
      final candidate = await Directory.systemTemp.createTemp(
        'nexa_release_cli_publisher_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      addTearDown(() => candidate.delete(recursive: true));
      for (final target in nexaHttpSupportedNativeTargets) {
        await File(
          p.join(candidate.path, target.releaseAssetFileName),
        ).writeAsString(target.rustTargetTriple);
      }
      final assembly = await assembleReleaseCandidate(
        candidateDirectory: candidate.path,
        version: '2.0.0',
        repository: 'iamdennisme/nexa_http',
      );
      final stdoutLines = <String>[];
      final commitSha = List<String>.filled(40, 'f').join();

      final exitCode = await runReleaseTransactionCli(
        <String>[
          'verify-publisher',
          '--workspace-root',
          workspace.path,
          '--repository',
          'iamdennisme/nexa_http',
          '--version',
          '2.0.0',
          '--commit-sha',
          commitSha,
          '--candidate-dir',
          candidate.path,
          '--candidate-id',
          'gha:42:314',
          '--candidate-digest',
          assembly.digest,
        ],
        resolveCommit: (sha) async => sha,
        isCommitOnMain: (_) async => true,
        tagExists: (_) async => false,
        releaseExists: (_) async => false,
        writeStdout: stdoutLines.add,
        writeStderr: (_) {},
      );

      expect(exitCode, 0);
      final json = jsonDecode(stdoutLines.single) as Map<String, Object?>;
      expect(json['candidate_id'], 'gha:42:314');
      expect(json['candidate_digest'], assembly.digest);
      expect(json['commit_sha'], commitSha);
    },
  );

  test('publish promotes only the preflighted candidate transaction', () async {
    final workspace = await _createWorkspaceVersions('2.0.0');
    final candidate = await Directory.systemTemp.createTemp(
      'nexa_release_cli_publish_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    addTearDown(() => candidate.delete(recursive: true));
    for (final target in nexaHttpSupportedNativeTargets) {
      await File(
        p.join(candidate.path, target.releaseAssetFileName),
      ).writeAsString(target.rustTargetTriple);
    }
    final assembly = await assembleReleaseCandidate(
      candidateDirectory: candidate.path,
      version: '2.0.0',
      repository: 'iamdennisme/nexa_http',
    );
    final remoteDigests = <String, String>{};
    for (final entity in candidate.listSync().whereType<File>()) {
      remoteDigests[p.basename(entity.path)] = await sha256OfFile(entity);
    }
    final gateway = _CliReleasePublicationGateway(remoteDigests);
    final stdoutLines = <String>[];
    final commitSha = List<String>.filled(40, 'a').join();

    final exitCode = await runReleaseTransactionCli(
      <String>[
        'publish',
        '--workspace-root',
        workspace.path,
        '--repository',
        'iamdennisme/nexa_http',
        '--version',
        '2.0.0',
        '--commit-sha',
        commitSha,
        '--candidate-dir',
        candidate.path,
        '--candidate-id',
        'gha:42:314',
        '--candidate-digest',
        assembly.digest,
      ],
      resolveCommit: (sha) async => sha,
      isCommitOnMain: (_) async => true,
      tagExists: (_) async => false,
      releaseExists: (_) async => false,
      publicationGateway: gateway,
      writeStdout: stdoutLines.add,
      writeStderr: (_) {},
    );

    expect(exitCode, 0);
    expect(gateway.createdTags, <String>['v2.0.0']);
    expect(jsonDecode(stdoutLines.single), containsPair('published', true));
  });
}

final class _CliReleasePublicationGateway implements ReleasePublicationGateway {
  _CliReleasePublicationGateway(this.remoteDigests);

  final Map<String, String> remoteDigests;
  final List<String> createdTags = <String>[];

  @override
  Future<void> createTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  }) async {
    createdTags.add(tag);
  }

  @override
  Future<void> createRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  }) async {}

  @override
  Future<void> deleteRelease({
    required String repository,
    required String tag,
  }) async {}

  @override
  Future<void> deleteTag({
    required String repository,
    required String tag,
  }) async {}

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
  }) async => false;

  @override
  Future<bool> ownsTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  }) async => false;

  @override
  Future<void> uploadAssets({
    required String repository,
    required String tag,
    required List<File> files,
  }) async {}
}

Future<Directory> _createWorkspaceVersions(String version) async {
  final root = await Directory.systemTemp.createTemp('nexa_release_cli_');
  for (final packageName in nexaHttpReleasePackageNames) {
    final packageDirectory = Directory(
      p.join(root.path, 'packages', packageName),
    );
    await packageDirectory.create(recursive: true);
    await File(
      p.join(packageDirectory.path, 'pubspec.yaml'),
    ).writeAsString('name: $packageName\nversion: $version\n');
  }
  return root;
}

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
