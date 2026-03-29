import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  final config = _Config.parse(args);

  await materializeDistributionWorkspace(
    workspaceRoot: Directory.current.path,
    outputDirectory: config.outputDirectory,
    requestedPackages: config.requestedPackages,
  );
}

Future<void> materializeDistributionWorkspace({
  required String workspaceRoot,
  required String outputDirectory,
  Set<String>? requestedPackages,
}) async {
  final root = Directory(workspaceRoot).absolute;
  final packagesDir = Directory(p.join(root.path, 'packages'));
  if (!packagesDir.existsSync()) {
    throw StateError('No packages directory found at ${packagesDir.path}.');
  }

  final packageDirs = _discoverTopLevelPackages(packagesDir);
  final selectedPackageNames =
      requestedPackages == null || requestedPackages.isEmpty
      ? packageDirs.keys.toSet()
      : requestedPackages;

  final missing = selectedPackageNames.difference(packageDirs.keys.toSet());
  if (missing.isNotEmpty) {
    throw StateError('Unknown package(s): ${missing.toList()..sort()}');
  }

  final packagesToCopy = <String>{};
  void addWithLocalDeps(String packageName) {
    if (!packagesToCopy.add(packageName)) {
      return;
    }
    final packageDir = packageDirs[packageName]!;
    for (final dependency in _localPathDependencies(
      root.path,
      packageDir.path,
    )) {
      addWithLocalDeps(dependency);
    }
  }

  for (final packageName in selectedPackageNames) {
    addWithLocalDeps(packageName);
  }

  _validateArtifacts(root.path, packagesToCopy, packageDirs);

  final outputDir = Directory(outputDirectory).absolute;
  if (outputDir.existsSync()) {
    await outputDir.delete(recursive: true);
  }
  await outputDir.create(recursive: true);

  for (final fileName in const ['pubspec.yaml']) {
    final source = File(p.join(root.path, fileName));
    if (source.existsSync()) {
      await source.copy(p.join(outputDir.path, fileName));
    }
  }

  for (final packageName in packagesToCopy) {
    final sourceDir = packageDirs[packageName]!;
    final relative = p.relative(sourceDir.path, from: root.path);
    final destinationDir = Directory(p.join(outputDir.path, relative));
    await _copyDirectoryFiltered(sourceDir, destinationDir);
  }
}

Map<String, Directory> _discoverTopLevelPackages(Directory packagesDir) {
  final result = <String, Directory>{};
  for (final entry in packagesDir.listSync(followLinks: false)) {
    if (entry is! Directory) {
      continue;
    }
    final pubspecFile = File(p.join(entry.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      continue;
    }
    final pubspec = _readPubspec(pubspecFile);
    final packageName = pubspec['name'] as String?;
    if (packageName == null || packageName.trim().isEmpty) {
      continue;
    }
    result[packageName.trim()] = entry.absolute;
  }
  return result;
}

Set<String> _localPathDependencies(String workspaceRoot, String packageDir) {
  final pubspec = _readPubspec(File(p.join(packageDir, 'pubspec.yaml')));
  final packageDeps = <String>{};

  for (final sectionName in const [
    'dependencies',
    'dev_dependencies',
    'dependency_overrides',
  ]) {
    final section = pubspec[sectionName];
    if (section is! YamlMap) {
      continue;
    }
    for (final entry in section.entries) {
      final packageName = '${entry.key}'.trim();
      final spec = entry.value;
      if (spec is! YamlMap || !spec.containsKey('path')) {
        continue;
      }
      final rawPath = '${spec['path']}'.trim();
      if (rawPath.isEmpty) {
        continue;
      }
      final resolved = Directory(
        p.normalize(p.join(packageDir, rawPath)),
      ).absolute;
      if (!p.isWithin(workspaceRoot, resolved.path)) {
        continue;
      }
      final pubspecFile = File(p.join(resolved.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        continue;
      }
      final dependencyPubspec = _readPubspec(pubspecFile);
      final resolvedName = dependencyPubspec['name'] as String?;
      if (resolvedName == null || resolvedName.trim().isEmpty) {
        continue;
      }
      packageDeps.add(resolvedName.trim());
      if (packageName != resolvedName.trim()) {
        packageDeps.add(packageName);
      }
    }
  }

  return packageDeps;
}

YamlMap _readPubspec(File pubspecFile) {
  final loaded = loadYaml(pubspecFile.readAsStringSync());
  if (loaded is! YamlMap) {
    throw StateError('Invalid pubspec at ${pubspecFile.path}.');
  }
  return loaded;
}

void _validateArtifacts(
  String workspaceRoot,
  Set<String> packageNames,
  Map<String, Directory> packageDirs,
) {
  for (final packageName in packageNames) {
    final required = _requiredArtifacts[packageName];
    if (required == null) {
      continue;
    }
    final packageDir = packageDirs[packageName]!;
    for (final relativePath in required) {
      final file = File(p.join(packageDir.path, relativePath));
      if (!file.existsSync()) {
        throw StateError(
          'Missing required artifact for $packageName: ${p.relative(file.path, from: workspaceRoot)}',
        );
      }
    }
  }
}

Future<void> _copyDirectoryFiltered(
  Directory sourceDir,
  Directory destinationDir,
) async {
  await destinationDir.create(recursive: true);

  await for (final entity in sourceDir.list(
    recursive: true,
    followLinks: false,
  )) {
    final relative = p.relative(entity.path, from: sourceDir.path);
    if (_shouldSkip(relative)) {
      continue;
    }
    final destinationPath = p.join(destinationDir.path, relative);
    if (entity is Directory) {
      await Directory(destinationPath).create(recursive: true);
      continue;
    }
    if (entity is File) {
      await File(destinationPath).parent.create(recursive: true);
      await entity.copy(destinationPath);
    }
  }
}

bool _shouldSkip(String relativePath) {
  final segments = p.split(relativePath);
  if (segments.contains('.dart_tool')) {
    return true;
  }
  if (segments.contains('.gradle')) {
    return true;
  }
  if (segments.contains('.idea')) {
    return true;
  }
  if (segments.contains('Pods')) {
    return true;
  }
  if (segments.contains('build')) {
    return true;
  }
  if (segments.contains('ephemeral')) {
    return true;
  }
  if (segments.contains('target')) {
    return true;
  }
  if (segments.contains('xcuserdata')) {
    return true;
  }
  if (segments.contains('.symlinks')) {
    return true;
  }
  final basename = p.basename(relativePath);
  if (basename == '.flutter-plugins' ||
      basename == '.flutter-plugins-dependencies' ||
      basename == 'Podfile.lock' ||
      basename == 'pubspec.lock' ||
      basename == 'pubspec_overrides.yaml' ||
      basename == 'local.properties') {
    return true;
  }
  if (basename.endsWith('.iml')) {
    return true;
  }
  return false;
}

final _requiredArtifacts = <String, List<String>>{
  'nexa_http_native_android': <String>[
    'android/src/main/jniLibs/arm64-v8a/libnexa_http_native.so',
    'android/src/main/jniLibs/armeabi-v7a/libnexa_http_native.so',
    'android/src/main/jniLibs/x86_64/libnexa_http_native.so',
  ],
  'nexa_http_native_ios': <String>[
    'ios/Frameworks/libnexa_http_native-ios-arm64.dylib',
    'ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib',
    'ios/Frameworks/libnexa_http_native-ios-sim-x64.dylib',
  ],
  'nexa_http_native_macos': <String>[
    'macos/Libraries/libnexa_http_native.dylib',
  ],
  'nexa_http_native_windows': <String>[
    'windows/Libraries/nexa_http_native.dll',
  ],
};

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
        stderr.writeln('Unknown argument: $argument');
        exit(64);
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
      stderr.writeln('Expected at least one package in --packages.');
      exit(64);
    }
    return packages;
  }
}
