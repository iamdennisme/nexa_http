import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../native_abi_verifier.dart';
import '../native_payload_identity.dart';
import 'candidate_set.dart';
import 'command.dart';
import 'external_consumer_adapter.dart';
import 'model.dart';
import 'report.dart';
import 'target_matrix.dart';

typedef CandidateSetLoader = Future<VerifiedCandidateSet> Function();
typedef CandidateNativePayloadIdentityDigester =
    Future<String> Function(File file, {required String platform});
typedef VerifiedCandidateConsumer =
    Future<void> Function(
      VerifiedCandidateSet candidate,
      VerificationExecutionId executionId,
    );
typedef VerifiedCandidateRuntimeConsumer =
    Future<List<VerificationRuntimePayloadProof>> Function(
      VerifiedCandidateSet candidate,
      VerificationExecutionId executionId,
    );

typedef CandidateAbiArtifactVerifier =
    Future<void> Function({
      required String workspaceRoot,
      required Map<NexaHttpNativeTarget, File> artifacts,
      required String candidateRef,
    });
typedef CandidateBuiltPayloadVerifier =
    Future<List<VerificationRuntimePayloadProof>> Function(
      VerificationExecutionId executionId,
      ExternalConsumerVerificationSession session,
      List<VerificationPreparedArtifactProof> preparedArtifactProofs,
    );

Future<List<VerificationPreparedArtifactProof>>
createCandidatePreparedArtifactProofs(
  VerifiedCandidateSet candidate,
  VerificationExecutionId executionId, {
  CandidateNativePayloadIdentityDigester identityDigest =
      nexaHttpNativePayloadIdentitySha256,
}) async {
  final row = buildReleaseCandidateExecutionRows().singleWhere(
    (candidateRow) => candidateRow.executionId == executionId,
    orElse: () => throw StateError(
      'No candidate proof target row for execution $executionId',
    ),
  );
  return List<VerificationPreparedArtifactProof>.unmodifiable(<
    VerificationPreparedArtifactProof
  >[
    for (final target in row.targets)
      await _candidatePreparedArtifactProof(candidate, target, identityDigest),
  ]);
}

Future<VerificationPreparedArtifactProof> _candidatePreparedArtifactProof(
  VerifiedCandidateSet candidate,
  NexaHttpNativeTarget target,
  CandidateNativePayloadIdentityDigester identityDigest,
) async {
  final file = candidate.artifactFiles[target.releaseAssetFileName];
  final digest = candidate.artifactDigests[target.releaseAssetFileName];
  if (file == null || digest == null) {
    throw StateError(
      'Verified candidate ${candidate.candidateId} is missing proof identity '
      'for ${target.releaseAssetFileName}',
    );
  }
  return VerificationPreparedArtifactProof(
    target: VerificationNativeTargetTuple(
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: target.targetSdk,
      rustTarget: target.rustTargetTriple,
    ),
    nativeAssetId: target.nativeAssetId,
    absolutePreparedFile: file.absolute.path,
    sha256: digest,
    identitySha256: await identityDigest(file, platform: target.targetOS),
    sourceIdentity: 'candidate:${candidate.candidateId}',
  );
}

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
          sdkRef: candidateRef,
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

VerifiedCandidateRuntimeConsumer createCandidateRuntimeConsumer({
  required String workspaceRoot,
  required Uri fixtureUrl,
  required String deviceId,
  required VerificationCommandRunner runCommand,
  required ExternalRuntimeProofMarkerTracker runtimeProofTracker,
  CandidateNativePayloadIdentityDigester identityDigest =
      nexaHttpNativePayloadIdentitySha256,
  CandidateBuiltPayloadVerifier verifyBuiltPayload =
      _verifyCandidateBuiltPayload,
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
    final preparedArtifactProofs = await createCandidatePreparedArtifactProofs(
      candidate,
      executionId,
      identityDigest: identityDigest,
    );
    final session = await createExternalConsumerSession(
      workspaceRoot: workspaceRoot,
      fixtureUrl: fixtureUrl,
      deviceIds: <String, String>{targetOS: deviceId},
      runCommand: runCommand,
      runtimeProofTracker: runtimeProofTracker,
      candidateDirectory: candidate.candidateDirectory.path,
      candidateRef: candidate.sdkRef,
      preparedArtifactProofs: preparedArtifactProofs,
    );
    try {
      await session.runner(executionId);
      return await verifyBuiltPayload(
        executionId,
        session,
        preparedArtifactProofs,
      );
    } finally {
      await session.close();
    }
  };
}

Future<List<VerificationRuntimePayloadProof>> _verifyCandidateBuiltPayload(
  VerificationExecutionId executionId,
  ExternalConsumerVerificationSession session,
  List<VerificationPreparedArtifactProof> preparedArtifactProofs,
) {
  return session.verifyArtifactUniqueness(executionId);
}

final class CandidateVerificationRunners {
  CandidateVerificationRunners({
    required CandidateSetLoader verifySet,
    required VerifiedCandidateConsumer verifyAbi,
    required VerifiedCandidateRuntimeConsumer verifyRuntime,
    CandidateNativePayloadIdentityDigester identityDigest =
        nexaHttpNativePayloadIdentitySha256,
  }) : _loadCandidate = verifySet,
       _verifyAbi = verifyAbi,
       _verifyRuntime = verifyRuntime,
       _identityDigest = identityDigest;

  final CandidateSetLoader _loadCandidate;
  final VerifiedCandidateConsumer _verifyAbi;
  final VerifiedCandidateRuntimeConsumer _verifyRuntime;
  final CandidateNativePayloadIdentityDigester _identityDigest;
  Future<VerifiedCandidateSet>? _verifiedCandidate;

  Future<void> verifySet(VerificationExecutionId executionId) async {
    await _loadOnce();
  }

  Future<void> verifyAbi(VerificationExecutionId executionId) async {
    await _verifyAbi(await _loadOnce(), executionId);
  }

  Future<List<VerificationRuntimePayloadProof>> verifyRuntime(
    VerificationExecutionId executionId,
  ) async {
    return _verifyRuntime(await _loadOnce(), executionId);
  }

  Future<List<VerificationPreparedArtifactProof>> preparedProofs(
    VerificationExecutionId executionId,
  ) async {
    return createCandidatePreparedArtifactProofs(
      await _loadOnce(),
      executionId,
      identityDigest: _identityDigest,
    );
  }

  Future<VerifiedCandidateSet> _loadOnce() {
    return _verifiedCandidate ??= _loadCandidate();
  }
}
