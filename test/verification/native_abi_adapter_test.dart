import 'package:test/test.dart';

import '../../scripts/native_abi_verifier.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/native_abi_adapter.dart';

void main() {
  test('maps explicit execution IDs to ABI hosts', () {
    expect(
      nativeAbiHostForExecution(const VerificationExecutionId('android-linux')),
      NexaHttpNativeAbiHost.android,
    );
    expect(
      nativeAbiHostForExecution(const VerificationExecutionId('apple-macos')),
      NexaHttpNativeAbiHost.apple,
    );
    expect(
      nativeAbiHostForExecution(const VerificationExecutionId('windows-x64')),
      NexaHttpNativeAbiHost.windows,
    );
  });

  test('ABI runner passes the explicit host to the native verifier', () async {
    String? receivedRoot;
    NexaHttpNativeAbiHost? receivedHost;
    final runner = createNativeAbiRunner(
      '/workspace',
      verify: (workspaceRoot, {required host}) async {
        receivedRoot = workspaceRoot;
        receivedHost = host;
      },
    );

    await runner(const VerificationExecutionId('apple-macos'));

    expect(receivedRoot, '/workspace');
    expect(receivedHost, NexaHttpNativeAbiHost.apple);
  });
}
