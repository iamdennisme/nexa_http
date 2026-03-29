import 'dart:io';

import 'package:path/path.dart' as p;

import 'materialize_distribution.dart';

typedef BuildScriptRunner = Future<void> Function(
  String scriptPath,
  String profile,
);

typedef MaterializeWorkspaceFn = Future<void> Function({
  required String workspaceRoot,
  required String outputDirectory,
  Set<String>? requestedPackages,
});

Future<void> main(List<String> args) async {
  final config = _Config.parse(args);
  await prepareDistributionWorkspace(
    workspaceRoot: Directory.current.path,
    outputDirectory: config.outputDirectory,
    requestedPackages: config.requestedPackages,
    profile: config.profile,
    skipBuild: config.skipBuild,
  );
}

Future<void> prepareDistributionWorkspace({
  required String workspaceRoot,
  required String outputDirectory,
  Set<String>? requestedPackages,
  String profile = 'release',
  bool skipBuild = false,
  BuildScriptRunner runBuildScript = _runBuildScript,
  MaterializeWorkspaceFn materializeWorkspace =
      materializeDistributionWorkspace,
}) async {
  late final List<String> packagesToBuild;
  if (requestedPackages == null || requestedPackages.isEmpty) {
    packagesToBuild = _buildScriptByPackage.keys.toList()..sort();
  } else {
    packagesToBuild = requestedPackages
        .where(_buildScriptByPackage.containsKey)
        .toList()
      ..sort();
  }

  if (!skipBuild) {
    final scriptsDir = p.join(workspaceRoot, 'scripts');
    for (final packageName in packagesToBuild) {
      final scriptName = _buildScriptByPackage[packageName]!;
      await runBuildScript(p.join(scriptsDir, scriptName), profile);
    }
  }

  await materializeWorkspace(
    workspaceRoot: workspaceRoot,
    outputDirectory: outputDirectory,
    requestedPackages: requestedPackages,
  );
}

Future<void> _runBuildScript(String scriptPath, String profile) async {
  final result = await Process.run(
    scriptPath,
    <String>[profile],
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      scriptPath,
      <String>[profile],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

const _buildScriptByPackage = <String, String>{
  'nexa_http_native_android': 'build_native_android.sh',
  'nexa_http_native_ios': 'build_native_ios.sh',
  'nexa_http_native_macos': 'build_native_macos.sh',
  'nexa_http_native_windows': 'build_native_windows.sh',
};

final class _Config {
  const _Config({
    required this.outputDirectory,
    required this.requestedPackages,
    required this.profile,
    required this.skipBuild,
  });

  final String outputDirectory;
  final Set<String>? requestedPackages;
  final String profile;
  final bool skipBuild;

  static _Config parse(List<String> args) {
    var outputDirectory = '.dist/materialized_workspace';
    Set<String>? requestedPackages;
    var profile = 'release';
    var skipBuild = false;

    for (var i = 0; i < args.length; i++) {
      final argument = args[i];
      if (argument == '--output-dir') {
        outputDirectory = args[++i];
      } else if (argument.startsWith('--output-dir=')) {
        outputDirectory = argument.substring('--output-dir='.length);
      } else if (argument == '--packages') {
        requestedPackages = _parsePackageList(args[++i]);
      } else if (argument.startsWith('--packages=')) {
        requestedPackages = _parsePackageList(
          argument.substring('--packages='.length),
        );
      } else if (argument == '--profile') {
        profile = args[++i];
      } else if (argument.startsWith('--profile=')) {
        profile = argument.substring('--profile='.length);
      } else if (argument == '--skip-build') {
        skipBuild = true;
      } else {
        stderr.writeln('Unknown argument: $argument');
        exit(64);
      }
    }

    if (profile != 'debug' && profile != 'release') {
      stderr.writeln('Unsupported --profile value: $profile');
      exit(64);
    }

    return _Config(
      outputDirectory: outputDirectory,
      requestedPackages: requestedPackages,
      profile: profile,
      skipBuild: skipBuild,
    );
  }

  static Set<String> _parsePackageList(String raw) {
    final packages = raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (packages.isEmpty) {
      stderr.writeln('Expected at least one package in --packages.');
      exit(64);
    }
    return packages;
  }
}
