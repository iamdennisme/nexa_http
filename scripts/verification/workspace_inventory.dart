import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

typedef WorkspacePackageDiscovery =
    Future<List<Directory>> Function(String workspaceRoot);

enum WorkspacePackageTool { dart, flutter }

final class WorkspacePackage {
  const WorkspacePackage({
    required this.directory,
    required this.relativePath,
    required this.tool,
    required this.hasTests,
  });

  final Directory directory;
  final String relativePath;
  final WorkspacePackageTool tool;
  final bool hasTests;
}

final class WorkspaceInventory {
  WorkspaceInventory(
    this.workspaceRoot, {
    WorkspacePackageDiscovery discoverPackages =
        discoverWorkspacePackageDirectories,
  }) : _discoverPackages = discoverPackages;

  final String workspaceRoot;
  final WorkspacePackageDiscovery _discoverPackages;
  Future<List<Directory>>? _packageDirectories;
  Future<List<WorkspacePackage>>? _packages;

  Future<List<Directory>> packageDirectories() {
    return _packageDirectories ??= _discoverPackages(
      workspaceRoot,
    ).then(List<Directory>.unmodifiable);
  }

  Future<List<WorkspacePackage>> packages() {
    return _packages ??= packageDirectories().then((directories) {
      return List<WorkspacePackage>.unmodifiable(
        directories.map((directory) {
          final pubspec = _readPubspec(
            File(p.join(directory.path, 'pubspec.yaml')),
          );
          return WorkspacePackage(
            directory: directory,
            relativePath: p.relative(directory.path, from: workspaceRoot),
            tool: _usesFlutter(pubspec)
                ? WorkspacePackageTool.flutter
                : WorkspacePackageTool.dart,
            hasTests: Directory(p.join(directory.path, 'test')).existsSync(),
          );
        }),
      );
    });
  }
}

YamlMap _readPubspec(File pubspecFile) {
  final loaded = loadYaml(pubspecFile.readAsStringSync());
  if (loaded is! YamlMap) {
    throw StateError('Invalid pubspec at ${pubspecFile.path}.');
  }
  return loaded;
}

bool _usesFlutter(YamlMap pubspec) {
  bool sectionHasFlutter(Object? section) {
    return section is YamlMap &&
        section['flutter'] is YamlMap &&
        (section['flutter'] as YamlMap)['sdk'] == 'flutter';
  }

  return sectionHasFlutter(pubspec['dependencies']) ||
      sectionHasFlutter(pubspec['dev_dependencies']) ||
      pubspec['flutter'] != null;
}

Future<List<Directory>> discoverWorkspacePackageDirectories(
  String workspaceRoot,
) async {
  final roots = <Directory>[
    Directory(p.join(workspaceRoot, 'packages')),
    Directory(p.join(workspaceRoot, 'app')),
  ];
  final directories = <String, Directory>{};

  for (final root in roots) {
    if (!root.existsSync()) {
      continue;
    }
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == 'pubspec.yaml') {
        directories[entity.parent.absolute.path] = entity.parent.absolute;
      }
    }
  }

  final result = directories.values.toList()
    ..sort(
      (left, right) => p
          .relative(left.path, from: workspaceRoot)
          .compareTo(p.relative(right.path, from: workspaceRoot)),
    );
  return result;
}
