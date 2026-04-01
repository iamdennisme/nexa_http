import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

typedef PackageCommandRunner = Future<void> Function(
  Directory packageDir,
  String executable,
  List<String> arguments,
);

const List<String> releaseTrainPackageNames = <String>[
  'nexa_http',
  'nexa_http_runtime',
  'nexa_http_distribution',
  'nexa_http_native_android',
  'nexa_http_native_ios',
  'nexa_http_native_macos',
  'nexa_http_native_windows',
];

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
    case 'check-release-train':
      await checkReleaseTrainVersions(workspaceRoot, args.skip(1).toList());
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
  verifyAlignedReleaseTrainVersions(workspaceRoot);
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

Map<String, String> readReleaseTrainPackageVersions(String workspaceRoot) {
  final versions = <String, String>{};
  for (final packageName in releaseTrainPackageNames) {
    final pubspecFile = File(
      p.join(workspaceRoot, 'packages', packageName, 'pubspec.yaml'),
    );
    if (!pubspecFile.existsSync()) {
      throw StateError(
        'Missing release-train pubspec for $packageName at ${pubspecFile.path}.',
      );
    }
    final pubspec = _readPubspec(pubspecFile);
    final version = (pubspec['version'] as String?)?.trim();
    if (version == null || version.isEmpty) {
      throw StateError(
        'Release-train package $packageName is missing a version in ${pubspecFile.path}.',
      );
    }
    versions[packageName] = version;
  }
  return versions;
}

String verifyAlignedReleaseTrainVersions(
  String workspaceRoot, {
  String? tagName,
}) {
  final versions = readReleaseTrainPackageVersions(workspaceRoot);
  final uniqueVersions = versions.values.toSet();
  if (uniqueVersions.length != 1) {
    final details = versions.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    throw StateError(
      'Release-train package versions must stay aligned across '
      '${releaseTrainPackageNames.join(', ')}. Found: $details',
    );
  }

  final alignedVersion = versions.values.first;
  if (tagName != null) {
    final normalizedTag = normalizeReleaseTagVersion(tagName);
    if (normalizedTag != alignedVersion) {
      throw StateError(
        'Release tag $tagName does not match aligned package version '
        '$alignedVersion.',
      );
    }
  }

  return alignedVersion;
}

String normalizeReleaseTagVersion(String tagName) {
  return tagName.startsWith('v') ? tagName.substring(1) : tagName;
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

Future<void> checkReleaseTrainVersions(
  String workspaceRoot,
  List<String> arguments,
) async {
  String? tagName;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--tag') {
      if (index + 1 >= arguments.length) {
        throw ArgumentError('Missing value for --tag.');
      }
      tagName = arguments[index + 1];
      index++;
      continue;
    }
    throw ArgumentError('Unknown check-release-train option: $argument');
  }

  final alignedVersion = verifyAlignedReleaseTrainVersions(
    workspaceRoot,
    tagName: tagName,
  );
  stdout.writeln(
    tagName == null
        ? 'Verified aligned release-train package version $alignedVersion.'
        : 'Verified aligned release-train package version $alignedVersion for tag $tagName.',
  );
}

Never _printUsageAndExit({int exitCode = 64}) {
  stderr.writeln(
    'Usage: dart run scripts/workspace_tools.dart '
    '<bootstrap|analyze|test|verify|check-release-train [--tag <tag>]>',
  );
  exit(exitCode);
}
