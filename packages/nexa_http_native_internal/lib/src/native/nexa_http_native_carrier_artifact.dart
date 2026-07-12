import 'dart:io';

import 'package:path/path.dart' as p;

import 'nexa_http_native_release_consumer.dart';
import 'nexa_http_native_target_matrix.dart';
import 'nexa_http_workspace_package.dart';

typedef NexaHttpNativeProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

Future<File> prepareNexaHttpNativeCarrierArtifact({
  required String packageRoot,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  NexaHttpNativeProcessRunner runProcess = runNexaHttpNativeProcess,
  NexaHttpNativeReleaseRefResolver resolveReleaseRef =
      discoverNexaHttpNativeGitReleaseRef,
  NexaHttpNativeFetchBytes fetchBytes = fetchNexaHttpNativeBytes,
  Map<String, String>? environment,
}) async {
  final target = findNexaHttpNativeTarget(
    targetOS: targetOS,
    targetArchitecture: targetArchitecture,
    targetSdk: targetSdk,
  );
  if (target == null) {
    throw NexaHttpNativeArtifactException(
      stage: 'native target resolution',
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      targetSdk: targetSdk,
      sdkRef: 'unknown',
      expectedAction:
          'Use a supported nexa_http native target, then rerun flutter pub get and flutter build/run.',
      underlyingError: StateError(
        'Unsupported native target: os=$targetOS architecture=$targetArchitecture sdk=$targetSdk.',
      ),
    );
  }

  final resolvedEnvironment = environment ?? Platform.environment;
  final candidateDirectory =
      resolvedEnvironment['NEXA_HTTP_NATIVE_CANDIDATE_DIR']?.trim() ?? '';
  if (candidateDirectory.isNotEmpty) {
    final candidateRef =
        resolvedEnvironment['NEXA_HTTP_NATIVE_CANDIDATE_REF']?.trim() ?? '';
    if (candidateRef.isEmpty) {
      throw StateError(
        'NEXA_HTTP_NATIVE_CANDIDATE_REF is required when '
        'NEXA_HTTP_NATIVE_CANDIDATE_DIR is set.',
      );
    }
    return materializeNexaHttpNativeCandidateArtifact(
      packageRoot: packageRoot,
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: target.targetSdk,
      candidateDirectory: candidateDirectory,
      candidateRef: candidateRef,
    );
  }

  if (shouldBuildNexaHttpNativeFromWorkspaceSource(
    packageRoot: packageRoot,
    buildScriptName: target.buildScriptName,
  )) {
    return prepareNexaHttpNativeWorkspaceArtifact(
      packageRoot: packageRoot,
      target: target,
      runProcess: runProcess,
    );
  }

  return materializeNexaHttpNativeReleaseArtifact(
    packageRoot: packageRoot,
    targetOS: target.targetOS,
    targetArchitecture: target.targetArchitecture,
    targetSdk: target.targetSdk,
    resolveReleaseRef: resolveReleaseRef,
    fetchBytes: fetchBytes,
  );
}

Future<File> prepareNexaHttpNativeWorkspaceArtifact({
  required String packageRoot,
  required NexaHttpNativeTarget target,
  NexaHttpNativeProcessRunner runProcess = runNexaHttpNativeProcess,
}) async {
  final artifactsDir = Directory(
    p.join(packageRoot, target.packagedDirectoryRelativePath),
  );
  if (artifactsDir.existsSync()) {
    await artifactsDir.delete(recursive: true);
  }

  final workspaceRoot = nexaHttpWorkspaceRootForPackage(packageRoot);
  final script = p.join(workspaceRoot, 'scripts', target.buildScriptName);
  final arguments = <String>[script, 'debug'];
  final result = await runProcess('bash', arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      'bash',
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }

  return File(p.join(packageRoot, target.packagedRelativePath));
}

Future<ProcessResult> runNexaHttpNativeProcess(
  String executable,
  List<String> arguments,
) {
  return Process.run(executable, arguments);
}
