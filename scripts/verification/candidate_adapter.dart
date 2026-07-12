import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../native_abi_verifier.dart';
import 'candidate_set.dart';
import 'command.dart';
import 'external_consumer_adapter.dart';
import 'model.dart';

typedef CandidateSetLoader = Future<VerifiedCandidateSet> Function();
typedef VerifiedCandidateConsumer =
    Future<void> Function(
      VerifiedCandidateSet candidate,
      VerificationExecutionId executionId,
    );

typedef CandidateAbiArtifactVerifier =
    Future<void> Function({
      required String workspaceRoot,
      required Map<NexaHttpNativeTarget, File> artifacts,
      required String candidateRef,
    });

VerifiedCandidateConsumer createCandidateAbiConsumer(
  String workspaceRoot, {
  CandidateAbiArtifactVerifier? verifyArtifacts,
}) {
  final resolvedVerifier =
      verifyArtifacts ??
      ({required workspaceRoot, required artifacts, required candidateRef}) {
        return verifyNexaHttpNativeAbiArtifacts(
          workspaceRoot,
          artifacts: artifacts,
          environment: <String, String>{
            ...Platform.environment,
            'NEXA_HTTP_NATIVE_CANDIDATE_REF': candidateRef,
          },
        );
      };
  return (candidate, executionId) {
    final targetOS = switch (executionId.value) {
      'candidate-android' => 'android',
      'candidate-ios' => 'ios',
      'candidate-macos' => 'macos',
      'candidate-windows' => 'windows',
      _ => throw StateError(
        'No candidate ABI platform mapping for execution $executionId',
      ),
    };
    final artifacts = <NexaHttpNativeTarget, File>{};
    for (final target in nexaHttpSupportedNativeTargets) {
      if (target.targetOS != targetOS) {
        continue;
      }
      final file = candidate.artifactFiles[target.releaseAssetFileName];
      if (file == null) {
        throw StateError(
          'Verified candidate ${candidate.candidateId} has no handle for '
          '${target.releaseAssetFileName}',
        );
      }
      artifacts[target] = file;
    }
    return resolvedVerifier(
      workspaceRoot: workspaceRoot,
      artifacts: artifacts,
      candidateRef: candidate.sdkRef,
    );
  };
}

VerifiedCandidateConsumer createCandidateRuntimeConsumer({
  required String workspaceRoot,
  required Uri fixtureUrl,
  required String deviceId,
  required VerificationCommandRunner runCommand,
}) {
  return (candidate, executionId) async {
    final targetOS = switch (executionId.value) {
      'candidate-android' => 'android',
      'candidate-ios' => 'ios',
      'candidate-macos' => 'macos',
      'candidate-windows' => 'windows',
      _ => throw StateError(
        'No candidate runtime platform mapping for execution $executionId',
      ),
    };
    final session = await createExternalConsumerSession(
      workspaceRoot: workspaceRoot,
      fixtureUrl: fixtureUrl,
      deviceIds: <String, String>{targetOS: deviceId},
      runCommand: runCommand,
      commandEnvironment: <String, String>{
        'NEXA_HTTP_NATIVE_CANDIDATE_DIR': candidate.candidateDirectory.path,
        'NEXA_HTTP_NATIVE_CANDIDATE_REF': candidate.sdkRef,
      },
    );
    try {
      await session.runner(executionId);
    } finally {
      await session.close();
    }
  };
}

final class CandidateVerificationRunners {
  CandidateVerificationRunners({
    required CandidateSetLoader verifySet,
    required VerifiedCandidateConsumer verifyAbi,
    required VerifiedCandidateConsumer verifyRuntime,
  }) : _loadCandidate = verifySet,
       _verifyAbi = verifyAbi,
       _verifyRuntime = verifyRuntime;

  final CandidateSetLoader _loadCandidate;
  final VerifiedCandidateConsumer _verifyAbi;
  final VerifiedCandidateConsumer _verifyRuntime;
  Future<VerifiedCandidateSet>? _verifiedCandidate;

  Future<void> verifySet(VerificationExecutionId executionId) async {
    await _loadOnce();
  }

  Future<void> verifyAbi(VerificationExecutionId executionId) async {
    await _verifyAbi(await _loadOnce(), executionId);
  }

  Future<void> verifyRuntime(VerificationExecutionId executionId) async {
    await _verifyRuntime(await _loadOnce(), executionId);
  }

  Future<VerifiedCandidateSet> _loadOnce() {
    return _verifiedCandidate ??= _loadCandidate();
  }
}
