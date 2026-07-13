import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'nexa_http_native_release_consumer.dart';
import 'nexa_http_native_shell.dart';
import 'nexa_http_native_target_matrix.dart';
import 'nexa_http_workspace_package.dart';

const nexaHttpNativeCandidateDirectoryDefine = 'candidate_directory';
const nexaHttpNativeCandidateRefDefine = 'candidate_ref';

typedef NexaHttpNativeProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef NexaHttpNativeArtifactPreparer =
    Future<File> Function({
      required String packageRoot,
      required String outputDirectory,
      required String targetOS,
      required String targetArchitecture,
      required String? targetSdk,
      String? candidateDirectory,
      String? candidateRef,
    });

Future<File> prepareNexaHttpNativeCarrierArtifact({
  required String packageRoot,
  required String outputDirectory,
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
  String? candidateDirectory,
  String? candidateRef,
  NexaHttpNativeProcessRunner runProcess = runNexaHttpNativeProcess,
  NexaHttpNativeReleaseRefResolver resolveReleaseRef =
      discoverNexaHttpNativeGitReleaseRef,
  NexaHttpNativeFetchStream fetchStream = fetchNexaHttpNativeStream,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
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

  final resolvedCandidateDirectory = candidateDirectory?.trim() ?? '';
  final resolvedCandidateRef = candidateRef?.trim() ?? '';
  if (resolvedCandidateDirectory.isNotEmpty ||
      resolvedCandidateRef.isNotEmpty) {
    if (resolvedCandidateDirectory.isEmpty || resolvedCandidateRef.isEmpty) {
      throw StateError(
        '$nexaHttpNativeCandidateDirectoryDefine and '
        '$nexaHttpNativeCandidateRefDefine must be provided together.',
      );
    }
    return materializeNexaHttpNativeCandidateArtifact(
      outputDirectory: outputDirectory,
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: target.targetSdk,
      candidateDirectory: resolvedCandidateDirectory,
      candidateRef: resolvedCandidateRef,
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
  required NexaHttpNativeTarget target,
  NexaHttpNativeProcessRunner runProcess = runNexaHttpNativeProcess,
  NexaHttpNativeBashResolver resolveBashExecutable =
      resolveNexaHttpNativeBashExecutable,
}) async {
  final workspaceRoot = nexaHttpWorkspaceRootForPackage(packageRoot);
  final script = p.join(workspaceRoot, 'scripts', target.buildScriptName);
  final targetOutputDirectory = Directory(
    nexaHttpNativeWorkspaceOutputDirectory(workspaceRoot),
  );
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
    final fingerprint = await nexaHttpNativeWorkspaceInputFingerprint(
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

String nexaHttpNativeWorkspaceOutputDirectory(String workspaceRoot) => p.join(
  Directory(workspaceRoot).absolute.path,
  '.dart_tool',
  'nexa_http_native',
  'workspace',
  'debug',
);

File nexaHttpNativeWorkspaceArtifactFile(
  String workspaceRoot,
  NexaHttpNativeTarget target,
) => File(
  p.join(
    nexaHttpNativeWorkspaceOutputDirectory(workspaceRoot),
    target.releaseAssetFileName,
  ),
).absolute;

Future<void> recordNexaHttpNativeWorkspaceArtifactFingerprint(
  String workspaceRoot,
  NexaHttpNativeTarget target,
) async {
  final artifact = nexaHttpNativeWorkspaceArtifactFile(workspaceRoot, target);
  if (!artifact.existsSync()) {
    throw StateError(
      'Cannot record workspace fingerprint for missing artifact: '
      '${artifact.path}',
    );
  }
  await File('${artifact.path}.workspace-input.sha256').writeAsString(
    await nexaHttpNativeWorkspaceInputFingerprint(workspaceRoot, target),
    flush: true,
  );
}

Future<String> nexaHttpNativeWorkspaceInputFingerprint(
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
    await _collectWorkspaceNativeSourceFiles(nativeRoot, files);
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
      await _collectWorkspaceNativeSourceFiles(packageNativeRoot, files);
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  final digest = await sha256
      .bind(_workspaceInputBytes(workspaceRoot, target, files))
      .first;
  return digest.toString();
}

Future<void> _collectWorkspaceNativeSourceFiles(
  Directory directory,
  List<File> files,
) async {
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File) {
      files.add(entity.absolute);
      continue;
    }
    if (entity is! Directory ||
        const <String>{
          'target',
          'build',
          '.dart_tool',
        }.contains(p.basename(entity.path))) {
      continue;
    }
    await _collectWorkspaceNativeSourceFiles(entity, files);
  }
}

Stream<List<int>> _workspaceInputBytes(
  String workspaceRoot,
  NexaHttpNativeTarget target,
  List<File> files,
) async* {
  yield utf8.encode(
    '${target.targetOS}:${target.targetArchitecture}:'
    '${target.targetSdk ?? 'none'}:${target.rustTargetTriple}\n',
  );
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
