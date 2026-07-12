import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'nexa_http_native_release_consumer.dart';
import 'nexa_http_native_shell.dart';
import 'nexa_http_native_target_matrix.dart';
import 'nexa_http_workspace_package.dart';

typedef NexaHttpNativeProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef NexaHttpNativeArtifactPreparer =
    Future<File> Function({
      required String packageRoot,
      required String outputDirectory,
      required String targetOS,
      required String targetArchitecture,
      required String? targetSdk,
    });

Future<File> prepareNexaHttpNativeCarrierArtifact({
  required String packageRoot,
  required String outputDirectory,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  NexaHttpNativeProcessRunner runProcess = runNexaHttpNativeProcess,
  NexaHttpNativeReleaseRefResolver resolveReleaseRef =
      discoverNexaHttpNativeGitReleaseRef,
  NexaHttpNativeFetchStream fetchStream = fetchNexaHttpNativeStream,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
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
      outputDirectory: outputDirectory,
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: target.targetSdk,
      candidateDirectory: candidateDirectory,
      candidateRef: candidateRef,
    );
  }

  final preparedDirectory =
      resolvedEnvironment['NEXA_HTTP_NATIVE_PREPARED_DIR']?.trim() ?? '';
  if (preparedDirectory.isNotEmpty) {
    final prepared = File(
      p.join(preparedDirectory, target.releaseAssetFileName),
    );
    if (!prepared.existsSync()) {
      throw NexaHttpNativeArtifactException(
        stage: 'prepared artifact resolution',
        targetOS: target.targetOS,
        targetArchitecture: target.targetArchitecture,
        targetSdk: target.targetSdk,
        sdkRef: 'workspace-integration',
        expectedAction:
            'Run the Catalog native-build producer for this execution before the clean-host consumer.',
        underlyingError: StateError(
          'Prepared Native Asset does not exist: ${prepared.path}',
        ),
      );
    }
    return prepared.absolute;
  }

  if (shouldBuildNexaHttpNativeFromWorkspaceSource(
    packageRoot: packageRoot,
    buildScriptName: target.buildScriptName,
  )) {
    return prepareNexaHttpNativeWorkspaceArtifact(
      packageRoot: packageRoot,
      outputDirectory: outputDirectory,
      target: target,
      runProcess: runProcess,
      resolveBashExecutable: resolveBashExecutable,
    );
  }

  return materializeNexaHttpNativeReleaseArtifact(
    packageRoot: packageRoot,
    outputDirectory: outputDirectory,
    targetOS: target.targetOS,
    targetArchitecture: target.targetArchitecture,
    targetSdk: target.targetSdk,
    resolveReleaseRef: resolveReleaseRef,
    fetchStream: fetchStream,
  );
}

Future<File> prepareNexaHttpNativeWorkspaceArtifact({
  required String packageRoot,
  required String outputDirectory,
  required NexaHttpNativeTarget target,
  NexaHttpNativeProcessRunner runProcess = runNexaHttpNativeProcess,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
}) async {
  final workspaceRoot = nexaHttpWorkspaceRootForPackage(packageRoot);
  final script = p.join(workspaceRoot, 'scripts', target.buildScriptName);
  final targetOutputDirectory = Directory(
    p.join(outputDirectory, target.materializationRelativePath('debug')),
  ).parent;
  await targetOutputDirectory.create(recursive: true);
  final destination = File(
    p.join(targetOutputDirectory.path, target.releaseAssetFileName),
  );
  final arguments = <String>[
    script,
    'debug',
    '--output-dir',
    targetOutputDirectory.path,
    '--target',
    target.rustTargetTriple,
  ];
  return withNexaHttpNativeArtifactLock(destination, () async {
    final fingerprint = await _workspaceNativeInputFingerprint(
      workspaceRoot,
      target,
    );
    final fingerprintFile = File('${destination.path}.workspace-input.sha256');
    if (destination.existsSync() &&
        fingerprintFile.existsSync() &&
        await fingerprintFile.readAsString() == fingerprint) {
      return destination;
    }

    final bashExecutable = await resolveBashExecutable();
    final result = await runProcess(bashExecutable, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        bashExecutable,
        arguments,
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
    if (!destination.existsSync()) {
      throw StateError(
        'Workspace native build completed without producing ${destination.path}',
      );
    }
    await fingerprintFile.writeAsString(fingerprint, flush: true);
    return destination;
  });
}

Future<String> _workspaceNativeInputFingerprint(
  String workspaceRoot,
  NexaHttpNativeTarget target,
) async {
  final files = <File>[];
  void addFile(String path) {
    final file = File(path);
    if (file.existsSync()) {
      files.add(file.absolute);
    }
  }

  addFile(p.join(workspaceRoot, 'Cargo.toml'));
  addFile(p.join(workspaceRoot, 'Cargo.lock'));
  addFile(p.join(workspaceRoot, 'scripts', 'build_native_common.sh'));
  addFile(p.join(workspaceRoot, 'scripts', target.buildScriptName));
  final nativeRoot = Directory(p.join(workspaceRoot, 'native'));
  if (nativeRoot.existsSync()) {
    await for (final entity in nativeRoot.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.absolute);
      }
    }
  }
  final packagesRoot = Directory(p.join(workspaceRoot, 'packages'));
  if (packagesRoot.existsSync()) {
    await for (final package in packagesRoot.list(followLinks: false)) {
      if (package is! Directory) {
        continue;
      }
      final packageNativeRoot = Directory(p.join(package.path, 'native'));
      if (!packageNativeRoot.existsSync()) {
        continue;
      }
      await for (final entity in packageNativeRoot.list(recursive: true)) {
        if (entity is File) {
          files.add(entity.absolute);
        }
      }
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  final digest = await sha256
      .bind(_workspaceInputBytes(workspaceRoot, files))
      .first;
  return digest.toString();
}

Stream<List<int>> _workspaceInputBytes(
  String workspaceRoot,
  List<File> files,
) async* {
  for (final file in files) {
    yield utf8.encode(p.relative(file.path, from: workspaceRoot));
    yield const <int>[0];
    yield* file.openRead();
    yield const <int>[0];
  }
}

Future<ProcessResult> runNexaHttpNativeProcess(
  String executable,
  List<String> arguments,
) {
  return Process.run(executable, arguments);
}
