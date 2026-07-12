import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../native_abi_verifier.dart';
import 'model.dart';

typedef NativeAbiVerifier =
    Future<void> Function(
      String workspaceRoot, {
      required Map<NexaHttpNativeTarget, File> artifacts,
    });

typedef NativeAbiExecutionRunner =
    Future<void> Function(
      List<VerifiedNativeArtifactIdentity> preparedArtifactIdentities,
    );

NativeAbiExecutionRunner createNativeAbiRunner(
  String workspaceRoot, {
  NativeAbiVerifier verify = verifyNexaHttpNativeAbiArtifacts,
}) {
  return (preparedArtifactIdentities) {
    return verify(
      workspaceRoot,
      artifacts: <NexaHttpNativeTarget, File>{
        for (final identity in preparedArtifactIdentities)
          identity.target: identity.file,
      },
    );
  };
}
