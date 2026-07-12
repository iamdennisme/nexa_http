import 'dart:io';

import 'materialize_distribution.dart';

typedef MaterializeWorkspaceFn =
    Future<void> Function({
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
  );
}

Future<void> prepareDistributionWorkspace({
  required String workspaceRoot,
  required String outputDirectory,
  Set<String>? requestedPackages,
  MaterializeWorkspaceFn materializeWorkspace =
      materializeDistributionWorkspace,
}) {
  return materializeWorkspace(
    workspaceRoot: workspaceRoot,
    outputDirectory: outputDirectory,
    requestedPackages: requestedPackages,
  );
}

final class _Config {
  const _Config({
    required this.outputDirectory,
    required this.requestedPackages,
  });

  final String outputDirectory;
  final Set<String>? requestedPackages;

  static _Config parse(List<String> args) {
    var outputDirectory = '.dist/materialized_workspace';
    Set<String>? requestedPackages;
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
      } else {
        throw ArgumentError('Unknown argument: $argument');
      }
    }
    return _Config(
      outputDirectory: outputDirectory,
      requestedPackages: requestedPackages,
    );
  }

  static Set<String> _parsePackageList(String raw) {
    final packages = raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (packages.isEmpty) {
      throw ArgumentError('Expected at least one package in --packages.');
    }
    return packages;
  }
}
