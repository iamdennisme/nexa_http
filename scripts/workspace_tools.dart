import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

typedef PackageCommandRunner = Future<void> Function(
  Directory packageDir,
  String executable,
  List<String> arguments,
);

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsageAndExit();
  }

  final command = args.first;
  final workspaceRoot = Directory.current.path;

  switch (command) {
    case 'bootstrap':
      await bootstrapWorkspacePackages(workspaceRoot);
      return;
    case 'analyze':
      await analyzeWorkspacePackages(workspaceRoot);
      return;
    case 'test':
      await testWorkspacePackages(workspaceRoot);
      return;
    case 'verify':
      await verifyWorkspacePackages(workspaceRoot);
      return;
    default:
      stderr.writeln('Unknown workspace command: $command');
      _printUsageAndExit(exitCode: 64);
  }
}

List<Directory> discoverWorkspacePackageDirs(String workspaceRoot) {
  final packagesRoot = Directory(p.join(workspaceRoot, 'packages'));
  if (!packagesRoot.existsSync()) {
    return const <Directory>[];
  }

  final directories = <Directory>{};
  for (final entity in packagesRoot.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || p.basename(entity.path) != 'pubspec.yaml') {
      continue;
    }
    directories.add(entity.parent.absolute);
  }
  final result = directories.toList()
    ..sort((left, right) => p.relative(left.path, from: workspaceRoot).compareTo(
          p.relative(right.path, from: workspaceRoot),
        ));
  return result;
}

Future<void> bootstrapWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['pub', 'get'],
    );
  }
}

Future<void> analyzeWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['analyze'],
    );
  }
}

Future<void> testWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    if (!Directory(p.join(packageDir.path, 'test')).existsSync()) {
      continue;
    }
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['test'],
    );
  }
}

Future<void> verifyWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['analyze'],
    );
    if (!Directory(p.join(packageDir.path, 'test')).existsSync()) {
      continue;
    }
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['test'],
    );
  }
}

bool _usesFlutter(Directory packageDir) {
  final pubspec = _readPubspec(File(p.join(packageDir.path, 'pubspec.yaml')));

  bool sectionHasFlutter(Object? section) {
    return section is YamlMap &&
        section['flutter'] is YamlMap &&
        (section['flutter'] as YamlMap)['sdk'] == 'flutter';
  }

  return sectionHasFlutter(pubspec['dependencies']) ||
      sectionHasFlutter(pubspec['dev_dependencies']) ||
      pubspec['flutter'] != null;
}

YamlMap _readPubspec(File pubspecFile) {
  final loaded = loadYaml(pubspecFile.readAsStringSync());
  if (loaded is! YamlMap) {
    throw StateError('Invalid pubspec at ${pubspecFile.path}.');
  }
  return loaded;
}

Future<void> _runPackageCommand(
  Directory packageDir,
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: packageDir.path,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

Never _printUsageAndExit({int exitCode = 64}) {
  stderr.writeln('Usage: dart run scripts/workspace_tools.dart <bootstrap|analyze|test|verify>');
  exit(exitCode);
}
