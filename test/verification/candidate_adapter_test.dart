import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/verification/candidate_adapter.dart';
import '../../scripts/verification/candidate_set.dart';
import '../../scripts/verification/command.dart';
import '../../scripts/verification/external_consumer_adapter.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/report.dart';

void main() {
  test('candidate ABI and runtime share one verified candidate set', () async {
    var verificationRuns = 0;
    final consumers = <String>[];
    final macosTargets = nexaHttpSupportedNativeTargets
        .where((target) => target.targetOS == 'macos')
        .toList(growable: false);
    final digest = List<String>.filled(64, 'a').join();
    final verified = VerifiedCandidateSet(
      candidateDirectory: Directory('/candidate'),
      candidateId: 'candidate-42',
      sdkRef: '20c3786',
      digest: digest,
      artifactDigests: <String, String>{
        for (final target in macosTargets) target.releaseAssetFileName: digest,
      },
      artifactFiles: <String, File>{
        for (final target in macosTargets)
          target.releaseAssetFileName: File(
            '/candidate/${target.releaseAssetFileName}',
          ),
      },
    );
    final runners = CandidateVerificationRunners(
      verifySet: () async {
        verificationRuns += 1;
        return verified;
      },
      verifyAbi: (candidate, executionId) async => consumers.add('abi'),
      verifyRuntime: (candidate, executionId, preparedArtifactProofs) async {
        consumers.add('runtime');
        return const <VerificationRuntimePayloadProof>[];
      },
      identityDigest: (file, {required platform}) async => digest,
    );
    const executionId = VerificationExecutionId('candidate-macos');

    await runners.verifySet(executionId);
    await runners.verifyAbi(executionId);
    await runners.verifyRuntime(executionId);

    expect(verificationRuns, 1);
    expect(consumers, <String>['abi', 'runtime']);
  });

  test(
    'candidate runners expose runtime proof without reloading the set',
    () async {
      var verificationRuns = 0;
      final macosTargets = nexaHttpSupportedNativeTargets
          .where((target) => target.targetOS == 'macos')
          .toList(growable: false);
      final digest = List<String>.filled(64, 'a').join();
      final verified = VerifiedCandidateSet(
        candidateDirectory: Directory('/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: digest,
        artifactDigests: <String, String>{
          for (final target in macosTargets)
            target.releaseAssetFileName: digest,
        },
        artifactFiles: <String, File>{
          for (final target in macosTargets)
            target.releaseAssetFileName: File(
              '/candidate/${target.releaseAssetFileName}',
            ),
        },
      );
      final proof = VerificationRuntimePayloadProof(
        target: VerificationNativeTargetTuple(
          targetOS: 'macos',
          targetArchitecture: 'arm64',
          targetSdk: null,
          rustTarget: 'aarch64-apple-darwin',
        ),
        nativeAssetId:
            'package:nexa_http_native_macos/src/native/'
            'nexa_http_native_ffi.dart',
        absolutePackagedFile: '/app/nexa_http-native-macos-arm64.dylib',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        identitySha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        payloadCount: 1,
        requestCompleted: true,
        callbackReceived: true,
        bodyConsumed: true,
        bodyReleased: true,
        clientClosed: true,
      );
      final receivedCandidates = <VerifiedCandidateSet>[];
      final runners = CandidateVerificationRunners(
        verifySet: () async {
          verificationRuns += 1;
          return verified;
        },
        verifyAbi: (candidate, executionId) async {
          receivedCandidates.add(candidate);
        },
        verifyRuntime: (candidate, executionId, preparedArtifactProofs) async {
          receivedCandidates.add(candidate);
          return <VerificationRuntimePayloadProof>[proof];
        },
        identityDigest: (file, {required platform}) async => digest,
      );
      const executionId = VerificationExecutionId('candidate-macos');

      await runners.verifySet(executionId);
      await runners.verifyAbi(executionId);
      final runtimeProofs = await runners.verifyRuntime(executionId);

      expect(verificationRuns, 1);
      expect(receivedCandidates, everyElement(same(verified)));
      expect(runtimeProofs, <VerificationRuntimePayloadProof>[proof]);
    },
  );

  test('candidate ABI selects only the blocking platform artifacts', () async {
    final files = <String, File>{
      for (final target in nexaHttpSupportedNativeTargets)
        target.releaseAssetFileName: File(
          '/candidate/${target.releaseAssetFileName}',
        ),
    };
    final candidate = VerifiedCandidateSet(
      candidateDirectory: Directory('/candidate'),
      candidateId: 'candidate-42',
      sdkRef: '20c3786',
      digest: List<String>.filled(64, 'a').join(),
      artifactDigests: const <String, String>{},
      artifactFiles: files,
    );
    Map<NexaHttpNativeTarget, File>? receivedArtifacts;
    String? receivedCandidateRef;
    final consumer = createCandidateAbiConsumer(
      '/workspace',
      verifyArtifacts:
          ({
            required workspaceRoot,
            required artifacts,
            required candidateRef,
          }) async {
            receivedArtifacts = artifacts;
            receivedCandidateRef = candidateRef;
          },
    );

    await consumer(candidate, const VerificationExecutionId('candidate-macos'));

    expect(
      receivedArtifacts!.keys.map((target) => target.targetOS).toSet(),
      <String>{'macos'},
    );
    expect(receivedArtifacts, hasLength(2));
    expect(receivedCandidateRef, '20c3786');
  });

  test(
    'candidate exposes prepared proofs for its canonical execution row',
    () async {
      const arm64Digest =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const x64Digest =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final files = <String, File>{
        for (final target in nexaHttpSupportedNativeTargets)
          target.releaseAssetFileName: File(
            '/candidate/${target.releaseAssetFileName}',
          ),
      };
      final digests = <String, String>{
        for (final target in nexaHttpSupportedNativeTargets)
          target.releaseAssetFileName: switch ((
            target.targetOS,
            target.targetArchitecture,
          )) {
            ('macos', 'arm64') => arm64Digest,
            ('macos', 'x64') => x64Digest,
            _ => List<String>.filled(64, 'c').join(),
          },
      };
      final candidate = VerifiedCandidateSet(
        candidateDirectory: Directory('/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: List<String>.filled(64, 'd').join(),
        artifactDigests: digests,
        artifactFiles: files,
      );

      final proofs = await createCandidatePreparedArtifactProofs(
        candidate,
        const VerificationExecutionId('candidate-macos'),
        identityDigest: (file, {required platform}) async =>
            digests[p.basename(file.path)]!,
      );

      expect(proofs, hasLength(2));
      expect(proofs.map((proof) => proof.target.targetOS).toSet(), <String>{
        'macos',
      });
      expect(proofs.map((proof) => proof.target.targetArchitecture), <String>[
        'arm64',
        'x64',
      ]);
      expect(proofs.map((proof) => proof.sha256), <String>[
        arm64Digest,
        x64Digest,
      ]);
      for (final proof in proofs) {
        final target = nexaHttpSupportedNativeTargets.singleWhere(
          (candidateTarget) =>
              candidateTarget.rustTargetTriple == proof.target.rustTarget,
        );
        expect(proof.nativeAssetId, target.nativeAssetId);
        expect(
          proof.absolutePreparedFile,
          files[target.releaseAssetFileName]!.absolute.path,
        );
        expect(
          proof.sourceIdentity,
          'candidate:candidate-42:'
          'dddddddddddddddddddddddddddddddd'
          'dddddddddddddddddddddddddddddddd',
        );
      }
    },
  );

  test(
    'Android and Windows prepared proofs reuse the verified artifact digest',
    () async {
      final directIdentityPlatforms = <String, VerificationExecutionId>{
        'android': const VerificationExecutionId('candidate-android'),
        'windows': const VerificationExecutionId('candidate-windows'),
      };
      final directIdentityTargets = nexaHttpSupportedNativeTargets
          .where(
            (target) => directIdentityPlatforms.containsKey(target.targetOS),
          )
          .toList(growable: false);
      final digest = List<String>.filled(64, 'a').join();
      final candidate = VerifiedCandidateSet(
        candidateDirectory: Directory('/candidate'),
        candidateId: 'gha:42:314',
        sdkRef: '20c3786',
        digest: List<String>.filled(64, 'd').join(),
        artifactDigests: <String, String>{
          for (final target in directIdentityTargets)
            target.releaseAssetFileName: digest,
        },
        artifactFiles: <String, File>{
          for (final target in directIdentityTargets)
            target.releaseAssetFileName: File(
              '/candidate/${target.releaseAssetFileName}',
            ),
        },
      );

      for (final entry in directIdentityPlatforms.entries) {
        final proofs = await createCandidatePreparedArtifactProofs(
          candidate,
          entry.value,
          identityDigest: (file, {required platform}) => throw StateError(
            '$platform must reuse the verified candidate digest',
          ),
        );

        final expectedTargetCount = directIdentityTargets
            .where((target) => target.targetOS == entry.key)
            .length;
        expect(proofs, hasLength(expectedTargetCount));
        expect(
          proofs.map((proof) => proof.identitySha256),
          everyElement(digest),
        );
      }
    },
  );

  test('verified candidate retains its original directory handle', () {
    final candidateDirectory = Directory('/staged/candidate');

    final candidate = VerifiedCandidateSet(
      candidateDirectory: candidateDirectory,
      candidateId: 'candidate-42',
      sdkRef: '20c3786',
      digest: List<String>.filled(64, 'a').join(),
      artifactDigests: const <String, String>{},
      artifactFiles: <String, File>{},
    );

    expect(candidate.candidateDirectory.path, '/staged/candidate');
  });

  test(
    'candidate runtime injects the verified staged source into the clean host',
    () async {
      final commands = <VerificationCommand>[];
      String? consumerPubspec;
      final macosTargets = nexaHttpSupportedNativeTargets
          .where((target) => target.targetOS == 'macos')
          .toList(growable: false);
      final candidate = VerifiedCandidateSet(
        candidateDirectory: Directory('/staged/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: List<String>.filled(64, 'a').join(),
        artifactDigests: <String, String>{
          for (final target in macosTargets)
            target.releaseAssetFileName: List<String>.filled(64, 'b').join(),
        },
        artifactFiles: <String, File>{
          for (final target in macosTargets)
            target.releaseAssetFileName: File(
              '/staged/candidate/${target.releaseAssetFileName}',
            ),
        },
      );
      final runtimeProofTracker = ExternalRuntimeProofMarkerTracker();
      final consumer = createCandidateRuntimeConsumer(
        workspaceRoot: Directory.current.path,
        fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
        deviceId: 'macos-id',
        runCommand: (command) async {
          commands.add(command);
          final pubspec = File(
            p.join(command.workingDirectory, 'pubspec.yaml'),
          );
          if (pubspec.existsSync()) {
            consumerPubspec = await pubspec.readAsString();
          }
          if (command.arguments case <String>[
            'create',
            '--platforms=macos',
            _,
            _,
          ]) {
            await _writeMacosEntitlementFixtures(command.workingDirectory);
          }
          if (command.arguments case <String>['run', ...]) {
            runtimeProofTracker.observeLine(_runtimeProofMarkerLine);
          }
        },
        runtimeProofTracker: runtimeProofTracker,
        verifyBuiltPayload: (_, _, _) async =>
            const <VerificationRuntimePayloadProof>[],
      );

      final preparedArtifactProofs =
          await createCandidatePreparedArtifactProofs(
            candidate,
            const VerificationExecutionId('candidate-macos'),
            identityDigest: (file, {required platform}) async =>
                candidate.artifactDigests[p.basename(file.path)]!,
          );

      await consumer(
        candidate,
        const VerificationExecutionId('candidate-macos'),
        preparedArtifactProofs,
      );

      expect(commands, hasLength(4));
      for (final command in commands) {
        expect(command.environment, isEmpty);
      }
      expect(consumerPubspec, contains('hooks:'));
      expect(consumerPubspec, contains('nexa_http_native_macos:'));
      expect(
        consumerPubspec,
        contains('candidate_directory: "/staged/candidate"'),
      );
      expect(consumerPubspec, contains('candidate_ref: "20c3786"'));
      expect(
        commands.last.arguments,
        containsAllInOrder(<String>['run', '-d', 'macos-id']),
      );
    },
  );

  test(
    'candidate runtime returns proof from the same clean host session',
    () async {
      const arm64Digest =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const x64Digest =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final macosTargets = nexaHttpSupportedNativeTargets
          .where((target) => target.targetOS == 'macos')
          .toList(growable: false);
      final candidate = VerifiedCandidateSet(
        candidateDirectory: Directory('/staged/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: List<String>.filled(64, 'd').join(),
        artifactDigests: <String, String>{
          macosTargets[0].releaseAssetFileName: arm64Digest,
          macosTargets[1].releaseAssetFileName: x64Digest,
        },
        artifactFiles: <String, File>{
          for (final target in macosTargets)
            target.releaseAssetFileName: File(
              '/staged/candidate/${target.releaseAssetFileName}',
            ),
        },
      );
      List<VerificationPreparedArtifactProof>? receivedPreparedProofs;
      final returnedRuntimeProofs = <VerificationRuntimePayloadProof>[
        VerificationRuntimePayloadProof(
          target: VerificationNativeTargetTuple(
            targetOS: 'macos',
            targetArchitecture: 'arm64',
            targetSdk: null,
            rustTarget: 'aarch64-apple-darwin',
          ),
          nativeAssetId: macosTargets.first.nativeAssetId,
          absolutePackagedFile: '/app/nexa_http-native-macos-arm64.dylib',
          sha256: arm64Digest,
          identitySha256: arm64Digest,
          payloadCount: 1,
          requestCompleted: true,
          callbackReceived: true,
          bodyConsumed: true,
          bodyReleased: true,
          clientClosed: true,
        ),
      ];
      final runtimeProofTracker = ExternalRuntimeProofMarkerTracker();
      final consumer = createCandidateRuntimeConsumer(
        workspaceRoot: Directory.current.path,
        fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
        deviceId: 'macos-id',
        runCommand: (command) async {
          if (command.arguments case <String>[
            'create',
            '--platforms=macos',
            _,
            _,
          ]) {
            await _writeMacosEntitlementFixtures(command.workingDirectory);
          }
          if (command.arguments case <String>['run', ...]) {
            runtimeProofTracker.observeLine(_runtimeProofMarkerLine);
          }
        },
        runtimeProofTracker: runtimeProofTracker,
        verifyBuiltPayload: (executionId, session, preparedProofs) async {
          receivedPreparedProofs = preparedProofs;
          return returnedRuntimeProofs;
        },
      );

      final preparedArtifactProofs =
          await createCandidatePreparedArtifactProofs(
            candidate,
            const VerificationExecutionId('candidate-macos'),
            identityDigest: (file, {required platform}) async =>
                candidate.artifactDigests[p.basename(file.path)]!,
          );

      final actual = await consumer(
        candidate,
        const VerificationExecutionId('candidate-macos'),
        preparedArtifactProofs,
      );

      expect(actual, same(returnedRuntimeProofs));
      expect(receivedPreparedProofs, hasLength(2));
      expect(receivedPreparedProofs!.map((proof) => proof.sha256), <String>[
        arm64Digest,
        x64Digest,
      ]);
      expect(
        receivedPreparedProofs!.map((proof) => proof.sourceIdentity).toSet(),
        <String>{
          'candidate:candidate-42:'
              'dddddddddddddddddddddddddddddddd'
              'dddddddddddddddddddddddddddddddd',
        },
      );
    },
  );
}

Future<void> _writeMacosEntitlementFixtures(String fixturePath) async {
  final runnerDirectory = Directory(p.join(fixturePath, 'macos', 'Runner'));
  await runnerDirectory.create(recursive: true);
  for (final name in <String>[
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    await File(p.join(runnerDirectory.path, name)).writeAsString('''
<plist version="1.0">
<dict>
</dict>
</plist>
''');
  }
}

const _runtimeProofMarkerLine =
    'flutter: NEXA_HTTP_RUNTIME_PROOF '
    '{"request_completed":true,"callback_received":true,'
    '"body_consumed":true,"body_released":true,"client_closed":true}';
