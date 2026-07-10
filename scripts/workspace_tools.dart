import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'native_abi_verifier.dart';

typedef PackageCommandRunner =
    Future<void> Function(
      Directory packageDir,
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
    });

enum WorkspaceHostPlatform { macos, windows, linux, other }

enum ConsumerDependencySource { git, path }

const List<String> workspaceVerificationCommands = <String>[
  'bootstrap',
  'analyze',
  'test',
  'verify',
  'verify-artifact-consistency',
  'verify-native-abi',
  'verify-development-path',
  'verify-external-consumer',
  'verify-release-consumer',
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
    case 'verify-artifact-consistency':
    case 'verify-artifacts':
      await verifyArtifactConsistency(workspaceRoot);
      return;
    case 'verify-native-abi':
      await verifyNexaHttpNativeAbi(
        workspaceRoot,
        host: currentNexaHttpNativeAbiHost(),
      );
      return;
    case 'verify-development-path':
    case 'verify-demo':
      await verifyDevelopmentPath(workspaceRoot);
      return;
    case 'verify-external-consumer':
      await verifyExternalConsumer(workspaceRoot);
      return;
    case 'verify-release-consumer':
      await verifyReleaseConsumer(
        workspaceRoot,
        repoUrl: Platform.environment['NEXA_HTTP_RELEASE_REPO_URL'],
        ref: Platform.environment['NEXA_HTTP_RELEASE_REF'],
      );
      return;
    default:
      stderr.writeln('Unknown workspace command: $command');
      _printUsageAndExit(exitCode: 64);
  }
}

List<Directory> discoverWorkspacePackageDirs(String workspaceRoot) {
  final roots = <Directory>[
    Directory(p.join(workspaceRoot, 'packages')),
    Directory(p.join(workspaceRoot, 'app')),
  ];

  final directories = <Directory>{};
  for (final root in roots) {
    if (!root.existsSync()) {
      continue;
    }
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || p.basename(entity.path) != 'pubspec.yaml') {
        continue;
      }
      directories.add(entity.parent.absolute);
    }
  }

  final result = directories.toList()
    ..sort(
      (left, right) => p
          .relative(left.path, from: workspaceRoot)
          .compareTo(p.relative(right.path, from: workspaceRoot)),
    );
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
  await verifyArtifactConsistency(
    workspaceRoot,
    runPackageCommand: runPackageCommand,
  );
  await verifyDevelopmentPath(
    workspaceRoot,
    runPackageCommand: runPackageCommand,
  );
  await verifyExternalConsumer(
    workspaceRoot,
    runPackageCommand: runPackageCommand,
  );
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
    throw StateError('Missing release workflow at ${workflowFile.path}.');
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

  final internalDir = Directory(
    p.join(workspaceRoot, 'packages', 'nexa_http_native_internal'),
  );
  if (Directory(p.join(internalDir.path, 'test')).existsSync()) {
    await runPackageCommand(internalDir, 'dart', const <String>['test']);
  }
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
  final resolvedHostPlatform = hostPlatform ?? currentWorkspaceHostPlatform();
  final demoDir = Directory(p.join(workspaceRoot, 'app', 'demo'));
  stdout.writeln('[verify-development-path] Cleaning demo app.');
  await runPackageCommand(demoDir, 'flutter', const <String>['clean']);
  stdout.writeln(
    '[verify-development-path] Running flutter pub get for demo app.',
  );
  await runPackageCommand(demoDir, 'flutter', const <String>['pub', 'get']);
  stdout.writeln(
    '[verify-development-path] Running flutter test for demo app.',
  );
  await runPackageCommand(demoDir, 'flutter', const <String>['test']);

  for (final buildArguments in demoBuildCommandsForHost(
    demoDir,
    resolvedHostPlatform,
  )) {
    stdout.writeln(
      '[verify-development-path] Running `flutter ${buildArguments.join(' ')}`.',
    );
    try {
      await runPackageCommand(demoDir, 'flutter', buildArguments);
    } on ProcessException catch (error) {
      if (isSkippableDemoBuildPrerequisiteFailure(error)) {
        stderr.writeln(
          'Skipping demo build `${buildArguments.join(' ')}` because a local platform prerequisite is missing:\n${error.message}',
        );
        continue;
      }
      rethrow;
    }
  }
  stdout.writeln('[verify-development-path] Passed.');
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

Future<void> verifyExternalConsumer(
  String workspaceRoot, {
  WorkspaceHostPlatform? hostPlatform,
  PackageCommandRunner runPackageCommand = _runPackageCommand,
  bool initializeGitRepository = true,
}) async {
  final resolvedHostPlatform = hostPlatform ?? currentWorkspaceHostPlatform();
  stdout.writeln(
    '[verify-external-consumer] Preparing external consumer fixture for $resolvedHostPlatform.',
  );
  final tempRoot = await Directory.systemTemp.createTemp(
    'nexa_http_external_consumer_',
  );
  try {
    final snapshotDir = Directory(p.join(tempRoot.path, 'repo'));
    await _copyWorkspaceForConsumerSnapshot(
      Directory(workspaceRoot),
      snapshotDir,
    );
    if (initializeGitRepository) {
      stdout.writeln(
        '[verify-external-consumer] Initializing temporary git snapshot.',
      );
      await _initializeTemporaryGitRepository(snapshotDir);
    }

    final repoUri = snapshotDir.absolute.uri.toString();
    await _runConsumerFixturePipeline(
      fixtureDir: Directory(p.join(tempRoot.path, 'consumer')),
      hostPlatform: resolvedHostPlatform,
      runPackageCommand: runPackageCommand,
      pubspecContents: buildExternalConsumerPubspecForHost(
        repoUri,
        resolvedHostPlatform,
        dependencySource: ConsumerDependencySource.path,
        includeRef: false,
      ),
      logPrefix: 'verify-external-consumer',
    );
  } finally {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<void> verifyReleaseConsumer(
  String workspaceRoot, {
  WorkspaceHostPlatform? hostPlatform,
  PackageCommandRunner runPackageCommand = _runPackageCommand,
  String? repoUrl,
  String? ref,
}) async {
  final resolvedHostPlatform = hostPlatform ?? currentWorkspaceHostPlatform();
  final resolvedRepoUrl =
      repoUrl ?? 'https://github.com/iamdennisme/nexa_http.git';
  final resolvedRef = _resolveReleaseConsumerRef(workspaceRoot, ref);
  await _runConsumerFixturePipeline(
    fixtureDir: Directory(
      p.join(workspaceRoot, '.claude', 'tmp', 'release_consumer_fixture'),
    ),
    hostPlatform: resolvedHostPlatform,
    runPackageCommand: runPackageCommand,
    pubspecContents: buildExternalConsumerPubspecForHost(
      resolvedRepoUrl,
      resolvedHostPlatform,
      ref: resolvedRef,
      includeRef: true,
    ),
    logPrefix: 'verify-release-consumer',
  );
}

Future<void> _runConsumerFixturePipeline({
  required Directory fixtureDir,
  required WorkspaceHostPlatform hostPlatform,
  required PackageCommandRunner runPackageCommand,
  required String pubspecContents,
  required String logPrefix,
}) async {
  stdout.writeln('[$logPrefix] Preparing consumer fixture for $hostPlatform.');
  if (fixtureDir.existsSync()) {
    await fixtureDir.delete(recursive: true);
  }
  await fixtureDir.create(recursive: true);

  stdout.writeln('[$logPrefix] Creating Flutter consumer app shell.');
  await runPackageCommand(
    fixtureDir,
    'flutter',
    consumerCreateArgumentsForHost(hostPlatform),
  );

  await File(
    p.join(fixtureDir.path, 'pubspec.yaml'),
  ).writeAsString(pubspecContents);
  final libDir = Directory(p.join(fixtureDir.path, 'lib'));
  await libDir.create(recursive: true);
  await File(
    p.join(libDir.path, 'main.dart'),
  ).writeAsString(buildExternalConsumerMainDart());

  stdout.writeln('[$logPrefix] Running flutter pub get for consumer.');
  await runPackageCommand(fixtureDir, 'flutter', const <String>['pub', 'get']);
  for (final buildArguments in consumerBuildCommandsForHost(
    fixtureDir,
    hostPlatform,
  )) {
    stdout.writeln(
      '[$logPrefix] Running `flutter ${buildArguments.join(' ')}`.',
    );
    await runPackageCommand(fixtureDir, 'flutter', buildArguments);
  }
  stdout.writeln('[$logPrefix] Passed.');
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
}) async {
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
  await for (final entity in source.list(
    recursive: false,
    followLinks: false,
  )) {
    final name = p.basename(entity.path);
    if (name == '.git' ||
        name == 'build' ||
        name == '.dart_tool' ||
        name == 'target') {
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
  await for (final entity in source.list(
    recursive: false,
    followLinks: false,
  )) {
    final name = p.basename(entity.path);
    if (name == '.dart_tool' || name == 'build' || name == 'target') {
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
  final commands = <List<String>>[
    <String>['init'],
    <String>['config', 'user.email', 'ci@example.invalid'],
    <String>['config', 'user.name', 'CI Fixture'],
    <String>['add', '-f', '.'],
    <String>['commit', '-m', 'snapshot'],
  ];
  for (final command in commands) {
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

String buildExternalConsumerPubspecForHost(
  String repoUrl,
  WorkspaceHostPlatform hostPlatform, {
  String? ref,
  bool includeRef = true,
  ConsumerDependencySource dependencySource = ConsumerDependencySource.git,
}) {
  if (hostPlatform == WorkspaceHostPlatform.other) {
    throw StateError(
      'No supported external consumer platform is defined for $hostPlatform.',
    );
  }
  final refBlock = includeRef ? '      ref: ${_requireGitRef(ref)}\n' : '';
  final dependencyBlock = switch (dependencySource) {
    ConsumerDependencySource.git => _gitConsumerDependencies(
      repoUrl,
      refBlock,
      hostPlatform,
    ),
    ConsumerDependencySource.path => _pathConsumerDependencies(
      repoUrl,
      hostPlatform,
    ),
  };

  return '''
name: nexa_http_external_consumer_fixture
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
$dependencyBlock
flutter:
  uses-material-design: true
''';
}

String _gitConsumerDependencies(
  String repoUrl,
  String refBlock,
  WorkspaceHostPlatform hostPlatform,
) {
  final platformPackage = platformPackageForHost(hostPlatform);
  return '''  nexa_http:
    git:
      url: $repoUrl
$refBlock      path: packages/nexa_http
  $platformPackage:
    git:
      url: $repoUrl
$refBlock      path: packages/$platformPackage''';
}

String _pathConsumerDependencies(
  String repoRoot,
  WorkspaceHostPlatform hostPlatform,
) {
  final platformPackage = platformPackageForHost(hostPlatform);
  final isFileUri = Uri.tryParse(repoRoot)?.isScheme('file') ?? false;
  final rootPath = isFileUri ? p.fromUri(Uri.parse(repoRoot)) : repoRoot;
  return '''  nexa_http:
    path: ${p.join(rootPath, 'packages', 'nexa_http')}
  $platformPackage:
    path: ${p.join(rootPath, 'packages', platformPackage)}''';
}

String platformPackageForHost(WorkspaceHostPlatform hostPlatform) {
  return switch (hostPlatform) {
    WorkspaceHostPlatform.macos => 'nexa_http_native_macos',
    WorkspaceHostPlatform.windows => 'nexa_http_native_windows',
    WorkspaceHostPlatform.linux => 'nexa_http_native_android',
    WorkspaceHostPlatform.other => throw StateError(
      'No supported external consumer platform package is defined for $hostPlatform.',
    ),
  };
}

String buildExternalConsumerMainDart() {
  return '''
import 'package:flutter/widgets.dart';
import 'package:nexa_http/nexa_http.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final client = NexaHttpClientBuilder()
      .callTimeout(const Duration(seconds: 5))
      .userAgent('nexa-http-clean-host/1.0')
      .build();
  final request = RequestBuilder()
      .url(Uri.parse('https://example.invalid/healthz'))
      .get()
      .build();

  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Text('\${client.userAgent}:\${request.method}'),
    ),
  );
}
''';
}

String _requireGitRef(String? ref) {
  final trimmed = ref?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == 'vX.Y.Z') {
    throw StateError(
      'A real git ref is required for git consumer verification. '
      'Use a release tag such as v2.0.0, not the vX.Y.Z placeholder.',
    );
  }
  return trimmed;
}

String _resolveReleaseConsumerRef(String workspaceRoot, String? explicitRef) {
  final trimmed = explicitRef?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return _requireGitRef(trimmed);
  }

  final headTag = _gitHeadTag(workspaceRoot);
  if (headTag != null) {
    return headTag;
  }

  throw StateError(
    'verify-release-consumer requires a real release git ref. '
    'Set NEXA_HTTP_RELEASE_REF to the release tag/ref, or run the command '
    'from a commit that is exactly tagged.',
  );
}

String? _gitHeadTag(String workspaceRoot) {
  try {
    final result = Process.runSync(
      'git',
      const <String>['describe', '--tags', '--exact-match', 'HEAD'],
      workingDirectory: workspaceRoot,
      runInShell: true,
    );
    if (result.exitCode == 0) {
      final tag = '${result.stdout}'.trim();
      if (tag.isNotEmpty) {
        return tag;
      }
    }
  } catch (_) {
    // fall through
  }
  return null;
}

String currentMacOsArchitecture() {
  return switch (ffi.Abi.current()) {
    ffi.Abi.macosArm64 => 'arm64',
    ffi.Abi.macosX64 => 'x64',
    _ => throw StateError('Unsupported macOS host ABI: ${ffi.Abi.current()}'),
  };
}

Never _printUsageAndExit({int exitCode = 64}) {
  stderr.writeln(
    'Usage: dart run scripts/workspace_tools.dart <bootstrap|analyze|test|verify|verify-artifact-consistency|verify-native-abi|verify-development-path|verify-external-consumer|verify-release-consumer>',
  );
  stderr.writeln(
    'For verify-release-consumer, set NEXA_HTTP_RELEASE_REF=<tag-or-ref> when HEAD is not exactly tagged.',
  );
  exit(exitCode);
}
