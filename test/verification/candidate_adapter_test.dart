import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../../scripts/verification/candidate_adapter.dart';
import '../../scripts/verification/candidate_set.dart';
import '../../scripts/verification/command.dart';
import '../../scripts/verification/model.dart';

void main() {
  test('candidate ABI and runtime share one verified candidate set', () async {
    var verificationRuns = 0;
    final consumers = <String>[];
    final verified = VerifiedCandidateSet(
      candidateDirectory: Directory('/candidate'),
      candidateId: 'candidate-42',
      sdkRef: '20c3786',
      digest: List<String>.filled(64, 'a').join(),
      artifactDigests: const <String, String>{},
      artifactFiles: <String, File>{},
    );
    final runners = CandidateVerificationRunners(
      verifySet: () async {
        verificationRuns += 1;
        return verified;
      },
      verifyAbi: (candidate, executionId) async => consumers.add('abi'),
      verifyRuntime: (candidate, executionId) async => consumers.add('runtime'),
    );
    const executionId = VerificationExecutionId('candidate-macos');

    await runners.verifySet(executionId);
    await runners.verifyAbi(executionId);
    await runners.verifyRuntime(executionId);

    expect(verificationRuns, 1);
    expect(consumers, <String>['abi', 'runtime']);
  });

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
      final candidate = VerifiedCandidateSet(
        candidateDirectory: Directory('/staged/candidate'),
        candidateId: 'candidate-42',
        sdkRef: '20c3786',
        digest: List<String>.filled(64, 'a').join(),
        artifactDigests: const <String, String>{},
        artifactFiles: <String, File>{},
      );
      final consumer = createCandidateRuntimeConsumer(
        workspaceRoot: Directory.current.path,
        fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
        deviceId: 'macos-id',
        runCommand: (command) async => commands.add(command),
      );

      await consumer(
        candidate,
        const VerificationExecutionId('candidate-macos'),
      );

      expect(commands, hasLength(4));
      for (final command in commands) {
        expect(command.environment, <String, String>{
          'NEXA_HTTP_NATIVE_CANDIDATE_DIR': '/staged/candidate',
          'NEXA_HTTP_NATIVE_CANDIDATE_REF': '20c3786',
        });
      }
      expect(
        commands.last.arguments,
        containsAllInOrder(<String>['run', '-d', 'macos-id']),
      );
    },
  );
}
