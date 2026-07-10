import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'native_abi_contract.dart';

enum NexaHttpNativeAbiHost { android, apple, windows }

typedef NexaHttpNativeSymbolCommandRunner =
    Future<NexaHttpNativeSymbolCommandResult> Function(
      NexaHttpNativeSymbolCommand command,
    );

final class NexaHttpNativeSymbolCommand {
  const NexaHttpNativeSymbolCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  String get display => <String>[executable, ...arguments].join(' ');
}

final class NexaHttpNativeSymbolCommandResult {
  const NexaHttpNativeSymbolCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

NexaHttpNativeAbiHost currentNexaHttpNativeAbiHost() {
  if (Platform.isMacOS) {
    return NexaHttpNativeAbiHost.apple;
  }
  if (Platform.isWindows) {
    return NexaHttpNativeAbiHost.windows;
  }
  if (Platform.isLinux) {
    return NexaHttpNativeAbiHost.android;
  }
  throw UnsupportedError(
    'Native ABI verification is not configured for ${Platform.operatingSystem}.',
  );
}

Future<void> verifyNexaHttpNativeAbi(
  String workspaceRoot, {
  required NexaHttpNativeAbiHost host,
  NexaHttpNativeSymbolCommandRunner runSymbolCommand =
      _runNexaHttpNativeSymbolCommand,
  Map<String, String>? environment,
}) async {
  final resolvedEnvironment = environment ?? Platform.environment;
  final artifacts = _nativeAbiArtifactsForHost(workspaceRoot, host);
  final sdkVersion = _readSdkVersion(workspaceRoot);
  final gitRef = _readGitRef(resolvedEnvironment);

  for (final artifact in artifacts) {
    if (!artifact.file.existsSync()) {
      throw StateError(
        _failureMessage(
          artifact,
          'expected_action=run ${artifact.buildScriptName} before verification; '
          'underlying_error=artifact does not exist',
          sdkVersion: sdkVersion,
          gitRef: gitRef,
        ),
      );
    }

    final attempt = await _readNativeSymbols(
      _symbolCommandsForArtifact(artifact, resolvedEnvironment),
      runSymbolCommand,
    );
    if (attempt.result == null) {
      throw StateError(
        _failureMessage(
          artifact,
          'expected_action=install a supported native symbol tool; '
          'underlying_error=${attempt.errors.join(' | ')}',
          sdkVersion: sdkVersion,
          gitRef: gitRef,
        ),
      );
    }

    final difference = compareNexaHttpPublicNativeAbiSymbols(
      nexaHttpSymbolsFromToolOutput(attempt.result!.stdout),
    );
    if (!difference.matches) {
      throw StateError(
        _failureMessage(
          artifact,
          'expected_action=rebuild the target artifact from current sources '
          'and review any intentional ABI change; '
          'underlying_error=public symbol set mismatch; '
          'command=${attempt.command!.display}; '
          'missing=${_formatSymbols(difference.missing)}; '
          'unexpected=${_formatSymbols(difference.unexpected)}',
          sdkVersion: sdkVersion,
          gitRef: gitRef,
        ),
      );
    }
  }
}

Future<NexaHttpNativeSymbolCommandResult> _runNexaHttpNativeSymbolCommand(
  NexaHttpNativeSymbolCommand command,
) async {
  try {
    final result = await Process.run(
      command.executable,
      command.arguments,
      runInShell: Platform.isWindows,
    );
    return NexaHttpNativeSymbolCommandResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  } on ProcessException catch (error) {
    return NexaHttpNativeSymbolCommandResult(
      exitCode: -1,
      stdout: '',
      stderr: error.message,
    );
  }
}

List<_NexaHttpNativeAbiArtifact> _nativeAbiArtifactsForHost(
  String workspaceRoot,
  NexaHttpNativeAbiHost host,
) {
  final targetOperatingSystems = switch (host) {
    NexaHttpNativeAbiHost.android => const <String>{'android'},
    NexaHttpNativeAbiHost.apple => const <String>{'ios', 'macos'},
    NexaHttpNativeAbiHost.windows => const <String>{'windows'},
  };
  final artifactsByPath = <String, _NexaHttpNativeAbiArtifact>{};

  for (final target in nexaHttpSupportedNativeTargets) {
    if (!targetOperatingSystems.contains(target.targetOS)) {
      continue;
    }
    final artifactPath = p.normalize(
      p.absolute(
        p.join(
          workspaceRoot,
          'packages',
          'nexa_http_native_${target.targetOS}',
          target.packagedRelativePath,
        ),
      ),
    );
    final targetDescription = <String>[
      target.targetOS,
      target.targetArchitecture,
      if (target.targetSdk != null) target.targetSdk!,
    ].join('/');
    final existing = artifactsByPath[artifactPath];
    if (existing == null) {
      artifactsByPath[artifactPath] = _NexaHttpNativeAbiArtifact(
        file: File(artifactPath),
        platform: target.targetOS,
        targets: <String>[targetDescription],
        buildScriptName: target.buildScriptName,
      );
    } else {
      existing.targets.add(targetDescription);
    }
  }

  return artifactsByPath.values.toList()
    ..sort((left, right) => left.file.path.compareTo(right.file.path));
}

List<NexaHttpNativeSymbolCommand> _symbolCommandsForArtifact(
  _NexaHttpNativeAbiArtifact artifact,
  Map<String, String> environment,
) {
  return switch (artifact.platform) {
    'android' => <NexaHttpNativeSymbolCommand>[
      ..._androidNdkLlvmNmCommands(artifact.file, environment),
      NexaHttpNativeSymbolCommand('llvm-nm', <String>[
        '-D',
        '--defined-only',
        artifact.file.path,
      ]),
      NexaHttpNativeSymbolCommand('nm', <String>[
        '-D',
        '--defined-only',
        artifact.file.path,
      ]),
    ],
    'ios' || 'macos' => <NexaHttpNativeSymbolCommand>[
      NexaHttpNativeSymbolCommand('/usr/bin/nm', <String>[
        '-gU',
        artifact.file.path,
      ]),
      NexaHttpNativeSymbolCommand('llvm-nm', <String>[
        '--defined-only',
        artifact.file.path,
      ]),
    ],
    'windows' => <NexaHttpNativeSymbolCommand>[
      NexaHttpNativeSymbolCommand('dumpbin', <String>[
        '/exports',
        artifact.file.path,
      ]),
      NexaHttpNativeSymbolCommand('llvm-readobj', <String>[
        '--coff-exports',
        artifact.file.path,
      ]),
      NexaHttpNativeSymbolCommand('llvm-nm', <String>[
        '--defined-only',
        artifact.file.path,
      ]),
    ],
    _ => throw UnsupportedError(
      'No native symbol command is configured for ${artifact.platform}.',
    ),
  };
}

List<NexaHttpNativeSymbolCommand> _androidNdkLlvmNmCommands(
  File artifact,
  Map<String, String> environment,
) {
  final commands = <NexaHttpNativeSymbolCommand>[];
  final ndkRoots = <String>{
    if (environment['ANDROID_NDK_ROOT'] case final value? when value.isNotEmpty)
      value,
    if (environment['ANDROID_NDK_HOME'] case final value? when value.isNotEmpty)
      value,
  };

  for (final ndkRoot in ndkRoots) {
    final prebuiltRoot = Directory(
      p.join(ndkRoot, 'toolchains', 'llvm', 'prebuilt'),
    );
    if (!prebuiltRoot.existsSync()) {
      continue;
    }
    for (final entity in prebuiltRoot.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final executable = File(
        p.join(
          entity.path,
          'bin',
          Platform.isWindows ? 'llvm-nm.exe' : 'llvm-nm',
        ),
      );
      if (executable.existsSync()) {
        commands.add(
          NexaHttpNativeSymbolCommand(executable.path, <String>[
            '-D',
            '--defined-only',
            artifact.path,
          ]),
        );
      }
    }
  }
  return commands;
}

Future<_NexaHttpNativeSymbolAttempt> _readNativeSymbols(
  List<NexaHttpNativeSymbolCommand> commands,
  NexaHttpNativeSymbolCommandRunner runSymbolCommand,
) async {
  final errors = <String>[];
  for (final command in commands) {
    try {
      final result = await runSymbolCommand(command);
      if (result.exitCode == 0) {
        return _NexaHttpNativeSymbolAttempt(
          command: command,
          result: result,
          errors: errors,
        );
      }
      errors.add(
        '${command.display}: exit=${result.exitCode}; stderr=${result.stderr.trim()}',
      );
    } on Object catch (error) {
      errors.add('${command.display}: $error');
    }
  }
  return _NexaHttpNativeSymbolAttempt(errors: errors);
}

String _failureMessage(
  _NexaHttpNativeAbiArtifact artifact,
  String details, {
  required String sdkVersion,
  required String gitRef,
}) {
  return 'nexa_http native ABI verification failed. '
      'stage=native ABI verification; '
      'platform=${artifact.platform}; '
      'target=${artifact.targets.join(',')}; '
      'artifact=${artifact.file.path}; '
      'sdk_version=$sdkVersion; '
      'git_ref=$gitRef; '
      '$details';
}

String _readSdkVersion(String workspaceRoot) {
  final pubspec = File(
    p.join(workspaceRoot, 'packages', 'nexa_http', 'pubspec.yaml'),
  );
  if (!pubspec.existsSync()) {
    return '<unknown>';
  }
  try {
    final document = loadYaml(pubspec.readAsStringSync());
    if (document is YamlMap) {
      final version = document['version'];
      if (version is String) {
        return version;
      }
    }
  } on Object {
    return '<unreadable>';
  }
  return '<unknown>';
}

String _readGitRef(Map<String, String> environment) {
  for (final key in <String>['GITHUB_SHA', 'NEXA_HTTP_RELEASE_REF']) {
    final value = environment[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return 'workspace';
}

String _formatSymbols(Set<String> symbols) {
  if (symbols.isEmpty) {
    return '<none>';
  }
  return (symbols.toList()..sort()).join(',');
}

final class _NexaHttpNativeAbiArtifact {
  const _NexaHttpNativeAbiArtifact({
    required this.file,
    required this.platform,
    required this.targets,
    required this.buildScriptName,
  });

  final File file;
  final String platform;
  final List<String> targets;
  final String buildScriptName;
}

final class _NexaHttpNativeSymbolAttempt {
  const _NexaHttpNativeSymbolAttempt({
    this.command,
    this.result,
    required this.errors,
  });

  final NexaHttpNativeSymbolCommand? command;
  final NexaHttpNativeSymbolCommandResult? result;
  final List<String> errors;
}
