import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../../scripts/verification/model.dart';
import '../../scripts/verification/native_abi_adapter.dart';

void main() {
  test(
    'ABI runner passes the producer-owned File handle to the verifier',
    () async {
      String? receivedRoot;
      Map<NexaHttpNativeTarget, File>? receivedArtifacts;
      final target = nexaHttpSupportedNativeTargets.first;
      final file = File('/tmp/prepared-android-arm64.so');
      final runner = createNativeAbiRunner(
        '/workspace',
        verify: (workspaceRoot, {required artifacts}) async {
          receivedRoot = workspaceRoot;
          receivedArtifacts = artifacts;
        },
      );

      await runner(<VerifiedNativeArtifactIdentity>[
        VerifiedNativeArtifactIdentity(
          target: target,
          file: file,
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          identitySha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          sourceIdentity: 'workspace',
        ),
      ]);

      expect(receivedRoot, '/workspace');
      expect(receivedArtifacts!.keys, <NexaHttpNativeTarget>[target]);
      expect(identical(receivedArtifacts![target], file), isTrue);
    },
  );
}
