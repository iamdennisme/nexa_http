import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

typedef PackageCommandRunner = Future<void> Function(
  Directory packageDir,
  String executable,
  List<String> arguments, {
    Map<String, String>? environment,
  }
);

enum WorkspaceHostPlatform { macos, windows, linux, other }

const List<String> releaseTrainPackageNames = <String>[
  'nexa_http',
  'nexa_http_runtime',
  'nexa_http_distribution',
  'nexa_http_native_android',
  'nexa_http_native_ios',
  'nexa_http_native_macos',
  'nexa_http_native_windows',
];

const List<String> workspaceVerificationCommands = <String>[
  'bootstrap',
  'analyze',
  'test',
  'verify',
  'verify-artifact-consistency',
  'verify-development-path',
  'verify-release-consumer',
  'check-release-train',
];

const _artifactModeEnvironmentVariable = 'NEXA_HTTP_NATIVE_ARTIFACT_MODE';

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
    case 'verify-artifact-consistency':
    case 'verify-artifacts':
      await verifyArtifactConsistency(workspaceRoot);
      return;
    case 'verify-development-path':
    case 'verify-demo':
      await verifyDevelopmentPath(workspaceRoot);
      return;
    case 'verify-release-consumer':
    case 'verify-external-consumer':
      await verifyReleaseConsumer(workspaceRoot);
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
  for (final entity
      in packagesRoot.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || p.basename(entity.path) != 'pubspec.yaml') {
      continue;
    }
    directories.add(entity.parent.absolute);
  }
  final result = directories.toList()
    ..sort(
        (left, right) => p.relative(left.path, from: workspaceRoot).compareTo(
              p.relative(right.path, from: workspaceRoot),
            ));
  return result;
}

Future<void> bootstrapWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    final environment = _workspaceDevelopmentEnvironmentForPackage(packageDir);
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['pub', 'get'],
      environment: environment,
    );
  }
}

Future<void> analyzeWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    final environment = _workspaceDevelopmentEnvironmentForPackage(packageDir);
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['analyze'],
      environment: environment,
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
    final environment = _workspaceDevelopmentEnvironmentForPackage(packageDir);
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['test'],
      environment: environment,
    );
  }
}

Future<void> verifyWorkspacePackages(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  verifyAlignedReleaseTrainVersions(workspaceRoot);
  await verifyArtifactConsistency(workspaceRoot,
      runPackageCommand: runPackageCommand);
  await verifyDevelopmentPath(workspaceRoot,
      runPackageCommand: runPackageCommand);
  await verifyReleaseConsumer(workspaceRoot,
      runPackageCommand: runPackageCommand);
  for (final packageDir in discoverWorkspacePackageDirs(workspaceRoot)) {
    final environment = _workspaceDevelopmentEnvironmentForPackage(packageDir);
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['analyze'],
      environment: environment,
    );
    if (!Directory(p.join(packageDir.path, 'test')).existsSync()) {
      continue;
    }
    await runPackageCommand(
      packageDir,
      _usesFlutter(packageDir) ? 'flutter' : 'dart',
      const <String>['test'],
      environment: environment,
    );
  }
}

List<String> releaseTrainNativeAssetFileNames() {
  return nexaHttpSupportedNativeTargets
      .map((target) => target.releaseAssetFileName)
      .toList(growable: false);
}

Future<void> verifyArtifactConsistency(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  final workflowFile = File(
    p.join(workspaceRoot, '.github', 'workflows', 'release-native-assets.yml'),
  );
  if (!workflowFile.existsSync()) {
    throw StateError(
      'Missing release workflow at ${workflowFile.path}.',
    );
  }

  final workflow = workflowFile.readAsStringSync();
  final expectedAssets = releaseTrainNativeAssetFileNames();
  for (final asset in expectedAssets) {
    if (!workflow.contains('dist/native-assets/$asset')) {
      throw StateError(
        'Release workflow is missing expected native asset staging for $asset.',
      );
    }
  }

  final windowsTarget = findNexaHttpNativeTarget(
    targetOS: 'windows',
    targetArchitecture: 'x64',
    targetSdk: null,
  );
  if (windowsTarget != null &&
      windowsTarget.rustTargetTriple != null &&
      !workflow.contains(windowsTarget.rustTargetTriple!)) {
    throw StateError(
      'Release workflow does not build the Windows target ${windowsTarget.rustTargetTriple}.',
    );
  }

  final distributionDir =
      Directory(p.join(workspaceRoot, 'packages', 'nexa_http_distribution'));
  await runPackageCommand(
    distributionDir,
    'dart',
    const <String>['test', 'test/nexa_http_native_release_manifest_test.dart'],
  );
}

Future<void> verifyArtifacts(
  String workspaceRoot, {
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) {
  return verifyArtifactConsistency(
    workspaceRoot,
    runPackageCommand: runPackageCommand,
  );
}

Future<void> verifyDevelopmentPath(
  String workspaceRoot, {
  WorkspaceHostPlatform? hostPlatform,
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  final exampleDir = Directory(
    p.join(workspaceRoot, 'packages', 'nexa_http', 'example'),
  );
  final environment = <String, String>{
    _artifactModeEnvironmentVariable: 'workspace-dev',
  };
  await runPackageCommand(
    exampleDir,
    'flutter',
    const <String>['pub', 'get'],
    environment: environment,
  );
  await runPackageCommand(
    exampleDir,
    'flutter',
    const <String>['test'],
    environment: environment,
  );

  for (final buildArguments in demoBuildCommandsForHost(
    exampleDir,
    hostPlatform ?? currentWorkspaceHostPlatform(),
  )) {
    try {
      await runPackageCommand(
        exampleDir,
        'flutter',
        buildArguments,
        environment: environment,
      );
    } on ProcessException catch (error) {
      if (isSkippableDemoBuildPrerequisiteFailure(error)) {
        stderr.writeln(
          'Skipping demo build `${buildArguments.join(' ')}` because a local platform prerequisite is missing:\n'
          '${error.message}',
        );
        continue;
      }
      rethrow;
    }
  }
}

Future<void> verifyDemo(
  String workspaceRoot, {
  WorkspaceHostPlatform? hostPlatform,
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) {
  return verifyDevelopmentPath(
    workspaceRoot,
    hostPlatform: hostPlatform,
    runPackageCommand: runPackageCommand,
  );
}

Future<void> verifyReleaseConsumer(
  String workspaceRoot, {
  WorkspaceHostPlatform? hostPlatform,
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) async {
  final resolvedHostPlatform =
      hostPlatform ?? currentWorkspaceHostPlatform();
  final tempRoot = await Directory.systemTemp.createTemp(
    'nexa_http_external_consumer_',
  );
  try {
    final snapshotDir = Directory(p.join(tempRoot.path, 'repo'));
    await _copyWorkspaceForConsumerSnapshot(
      Directory(workspaceRoot),
      snapshotDir,
    );
    await _initializeTemporaryGitRepository(snapshotDir);

    final consumerDir = Directory(p.join(tempRoot.path, 'consumer'));
    await consumerDir.create(recursive: true);
    final environment = await _releaseConsumerEnvironment(
      workspaceRoot: workspaceRoot,
      tempRoot: tempRoot,
      hostPlatform: resolvedHostPlatform,
    );

    await runPackageCommand(
      consumerDir,
      'flutter',
      consumerCreateArgumentsForHost(resolvedHostPlatform),
      environment: environment,
    );

    final repoUri = snapshotDir.absolute.uri.toString();
    await File(p.join(consumerDir.path, 'pubspec.yaml')).writeAsString(
      _buildExternalConsumerPubspec(repoUri),
    );
    final libDir = Directory(p.join(consumerDir.path, 'lib'));
    await libDir.create(recursive: true);
    await File(p.join(libDir.path, 'main.dart')).writeAsString(
      "void main() {}\n",
    );

    await runPackageCommand(
      consumerDir,
      'flutter',
      const <String>['pub', 'get'],
      environment: environment,
    );
    for (final buildArguments in consumerBuildCommandsForHost(
      consumerDir,
      resolvedHostPlatform,
    )) {
      await runPackageCommand(
        consumerDir,
        'flutter',
        buildArguments,
        environment: environment,
      );
    }
  } finally {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<void> verifyExternalConsumer(
  String workspaceRoot, {
  WorkspaceHostPlatform? hostPlatform,
  PackageCommandRunner runPackageCommand = _runPackageCommand,
}) {
  return verifyReleaseConsumer(
    workspaceRoot,
    hostPlatform: hostPlatform,
    runPackageCommand: runPackageCommand,
  );
}

Future<Map<String, String>> _releaseConsumerEnvironment({
  required String workspaceRoot,
  required Directory tempRoot,
  required WorkspaceHostPlatform hostPlatform,
}) async {
  final stagedAssetsDir = Directory(p.join(tempRoot.path, 'release-assets'));
  await stagedAssetsDir.create(recursive: true);

  final assetEntries = <Map<String, Object?>>[];
  for (final target in _releaseConsumerTargetsForHost(hostPlatform)) {
    final sourceFile = File(
      p.join(
        workspaceRoot,
        'packages',
        _packageNameForTarget(target),
        target.packagedRelativePath,
      ),
    );
    if (!sourceFile.existsSync()) {
      throw StateError(
        'Missing local release-consumer fixture asset for '
        '${target.targetOS}/${target.targetArchitecture}${target.targetSdk == null ? '' : ' (${target.targetSdk})'}: '
        '${p.relative(sourceFile.path, from: workspaceRoot)}. '
        'Prepare the host native artifact before verifying the external consumer path.',
      );
    }

    final destination = File(
      p.join(stagedAssetsDir.path, target.releaseAssetFileName),
    );
    await destination.parent.create(recursive: true);
    await sourceFile.copy(destination.path);
    assetEntries.add(<String, Object?>{
      'target_os': target.targetOS,
      'target_architecture': target.targetArchitecture,
      if (target.targetSdk != null) 'target_sdk': target.targetSdk,
      'file_name': target.releaseAssetFileName,
      'source_url': destination.absolute.uri.toString(),
      'sha256': await sha256OfFile(destination),
    });
  }

  final packageVersion = readReleaseTrainPackageVersions(workspaceRoot)['nexa_http']!;
  final manifestFile = File(
    p.join(tempRoot.path, nexaHttpNativeAssetsManifestFileName),
  );
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'package': 'nexa_http',
      'package_version': packageVersion,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'assets': assetEntries,
    }),
  );

  return <String, String>{
    _artifactModeEnvironmentVariable: 'release-consumer',
    'NEXA_HTTP_NATIVE_MANIFEST_PATH': manifestFile.path,
  };
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

Map<String, String>? _workspaceDevelopmentEnvironmentForPackage(
  Directory packageDir,
) {
  if (!_usesFlutter(packageDir)) {
    return null;
  }
  return const <String, String>{
    _artifactModeEnvironmentVariable: 'workspace-dev',
  };
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
  List<String> arguments, {
    Map<String, String>? environment,
  }
) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: packageDir.path,
    runInShell: true,
    environment: environment == null
        ? null
        : <String, String>{...Platform.environment, ...environment},
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

Future<void> _copyWorkspaceForConsumerSnapshot(
  Directory source,
  Directory destination,
) async {
  await destination.create(recursive: true);
  await for (final entity
      in source.list(recursive: false, followLinks: false)) {
    final name = p.basename(entity.path);
    if (name == '.git' || name == 'build' || name == '.dart_tool') {
      continue;
    }
    final targetPath = p.join(destination.path, name);
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await File(targetPath).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity
      in source.list(recursive: false, followLinks: false)) {
    final name = p.basename(entity.path);
    if (name == '.dart_tool' || name == 'build') {
      continue;
    }
    final targetPath = p.join(destination.path, name);
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await File(targetPath).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

Future<void> _initializeTemporaryGitRepository(Directory repository) async {
  for (final command in <List<String>>[
    <String>['init'],
    <String>['config', 'user.email', 'ci@example.invalid'],
    <String>['config', 'user.name', 'CI Fixture'],
    <String>['add', '-f', '.'],
    <String>['commit', '-m', 'snapshot'],
  ]) {
    final result = await Process.run(
      'git',
      command,
      workingDirectory: repository.path,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        command,
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
  }
}

WorkspaceHostPlatform currentWorkspaceHostPlatform() {
  if (Platform.isMacOS) {
    return WorkspaceHostPlatform.macos;
  }
  if (Platform.isWindows) {
    return WorkspaceHostPlatform.windows;
  }
  if (Platform.isLinux) {
    return WorkspaceHostPlatform.linux;
  }
  return WorkspaceHostPlatform.other;
}

List<List<String>> demoBuildCommandsForHost(
  Directory exampleDir,
  WorkspaceHostPlatform hostPlatform,
) {
  bool hasPlatform(String name) =>
      Directory(p.join(exampleDir.path, name)).existsSync();

  return switch (hostPlatform) {
    WorkspaceHostPlatform.macos => <List<String>>[
        if (hasPlatform('macos')) <String>['build', 'macos', '--debug'],
        if (hasPlatform('ios'))
          <String>['build', 'ios', '--simulator', '--debug', '--no-codesign'],
      ],
    WorkspaceHostPlatform.windows => <List<String>>[
        if (hasPlatform('windows')) <String>['build', 'windows', '--debug'],
      ],
    WorkspaceHostPlatform.linux => <List<String>>[
        if (hasPlatform('android')) <String>['build', 'apk', '--debug'],
      ],
    WorkspaceHostPlatform.other => const <List<String>>[],
  };
}

List<List<String>> consumerBuildCommandsForHost(
  Directory consumerDir,
  WorkspaceHostPlatform hostPlatform,
) {
  bool hasPlatform(String name) =>
      Directory(p.join(consumerDir.path, name)).existsSync();

  return switch (hostPlatform) {
    WorkspaceHostPlatform.macos => <List<String>>[
        if (hasPlatform('macos')) <String>['build', 'macos', '--debug'],
      ],
    WorkspaceHostPlatform.windows => <List<String>>[
        if (hasPlatform('windows')) <String>['build', 'windows', '--debug'],
      ],
    WorkspaceHostPlatform.linux => <List<String>>[
        if (hasPlatform('android')) <String>['build', 'apk', '--debug'],
      ],
    WorkspaceHostPlatform.other => const <List<String>>[],
  };
}

List<String> consumerCreateArgumentsForHost(
  WorkspaceHostPlatform hostPlatform,
) {
  final platforms = switch (hostPlatform) {
    WorkspaceHostPlatform.macos => 'macos',
    WorkspaceHostPlatform.windows => 'windows',
    WorkspaceHostPlatform.linux => 'android',
    WorkspaceHostPlatform.other => '',
  };

  return <String>[
    'create',
    if (platforms.isNotEmpty) '--platforms=$platforms',
    '--project-name=nexa_http_external_consumer_fixture',
    '.',
  ];
}

bool isSkippableDemoBuildPrerequisiteFailure(ProcessException error) {
  final message = '${error.message}'.toLowerCase();
  return message.contains('platform:ios simulator') &&
      (message.contains('is not installed') ||
          message.contains('unable to find a destination'));
}

Iterable<NexaHttpNativeTarget> _releaseConsumerTargetsForHost(
  WorkspaceHostPlatform hostPlatform,
) {
  return switch (hostPlatform) {
    WorkspaceHostPlatform.macos => <NexaHttpNativeTarget>[
        findNexaHttpNativeTarget(
          targetOS: 'macos',
          targetArchitecture: _currentMacOsArchitecture(),
          targetSdk: null,
        )!,
      ],
    WorkspaceHostPlatform.windows => <NexaHttpNativeTarget>[
        findNexaHttpNativeTarget(
          targetOS: 'windows',
          targetArchitecture: 'x64',
          targetSdk: null,
        )!,
      ],
    WorkspaceHostPlatform.linux => nexaHttpSupportedNativeTargets.where(
        (target) => target.targetOS == 'android',
      ),
    WorkspaceHostPlatform.other => const <NexaHttpNativeTarget>[],
  };
}

String _packageNameForTarget(NexaHttpNativeTarget target) {
  return switch (target.targetOS) {
    'android' => 'nexa_http_native_android',
    'ios' => 'nexa_http_native_ios',
    'macos' => 'nexa_http_native_macos',
    'windows' => 'nexa_http_native_windows',
    _ => throw StateError('Unsupported native target OS: ${target.targetOS}'),
  };
}

String _currentMacOsArchitecture() {
  return switch (ffi.Abi.current()) {
    ffi.Abi.macosArm64 => 'arm64',
    ffi.Abi.macosX64 => 'x64',
    _ => throw StateError(
        'Unsupported macOS host ABI for release-consumer verification: ${ffi.Abi.current()}',
      ),
  };
}

String _buildExternalConsumerPubspec(String repoUrl) {
  return '''
name: nexa_http_external_consumer_fixture
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  nexa_http:
    git:
      url: $repoUrl
      path: packages/nexa_http
      ref: master

flutter:
  uses-material-design: true
''';
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
    '<bootstrap|analyze|test|verify|verify-artifact-consistency|verify-development-path|verify-release-consumer|check-release-train [--tag <tag>]>',
  );
  exit(exitCode);
}
