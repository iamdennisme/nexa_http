import '../native_abi_verifier.dart';
import 'model.dart';

typedef NativeAbiVerifier =
    Future<void> Function(
      String workspaceRoot, {
      required NexaHttpNativeAbiHost host,
    });

typedef NativeAbiExecutionRunner =
    Future<void> Function(VerificationExecutionId executionId);

NativeAbiExecutionRunner createNativeAbiRunner(
  String workspaceRoot, {
  NativeAbiVerifier verify = verifyNexaHttpNativeAbi,
}) {
  return (executionId) {
    return verify(workspaceRoot, host: nativeAbiHostForExecution(executionId));
  };
}

NexaHttpNativeAbiHost nativeAbiHostForExecution(
  VerificationExecutionId executionId,
) {
  return switch (executionId.value) {
    'android-linux' => NexaHttpNativeAbiHost.android,
    'apple-macos' => NexaHttpNativeAbiHost.apple,
    'windows-x64' => NexaHttpNativeAbiHost.windows,
    _ => throw StateError(
      'No native ABI host mapping for execution $executionId',
    ),
  };
}
