import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import '../lib/src/nexa_http_native_macos_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.macOS) {
      return;
    }

    final target = findNexaHttpNativeTarget(
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: null,
    );
    if (target == null) {
      return;
    }

    final sourceDir = p.normalize(
      p.join(
        Directory.fromUri(input.packageRoot).path,
        'native',
        'nexa_http_native_macos_ffi',
      ),
    );
    final buildEnvironment = await _buildEnvironmentForTarget(target);
    final result = await Process.run(
      'cargo',
      cargoBuildArgumentsForNexaHttpTarget(sourceDir, target),
      environment: buildEnvironment.isEmpty ? null : buildEnvironment,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'cargo',
        cargoBuildArgumentsForNexaHttpTarget(sourceDir, target),
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }

    final file = File(_builtArtifactPathForMacosTarget(sourceDir, target));
    if (!await file.exists()) {
      throw StateError('Missing macOS native artifact: ${file.path}');
    }

    await _stagePackagedMacosLibrary(
      packageRoot: Directory.fromUri(input.packageRoot).path,
      file: file,
    );

    output.assets.code.add(
      await NexaHttpNativeMacosAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}

List<String> cargoBuildArgumentsForNexaHttpTarget(
  String sourceDir,
  NexaHttpNativeTarget target,
) {
  final targetFlag = _macosCargoTargetFlag(target);
  return <String>[
    'build',
    '--manifest-path',
    p.join(sourceDir, 'Cargo.toml'),
    ...targetFlag,
  ];
}

Future<Map<String, String>> _buildEnvironmentForTarget(
  NexaHttpNativeTarget target,
) async {
  if (target.targetOS != 'macos') {
    return const <String, String>{};
  }

  final sdkRoot = await _resolveMacosSdkRoot();
  if (sdkRoot == null || sdkRoot.isEmpty) {
    return const <String, String>{};
  }

  return cargoBuildEnvironmentForNexaHttpTarget(
    target: target,
    sdkRoot: sdkRoot,
  );
}

Map<String, String> cargoBuildEnvironmentForNexaHttpTarget({
  required NexaHttpNativeTarget target,
  required String sdkRoot,
}) {
  if (target.targetOS != 'macos' || sdkRoot.trim().isEmpty) {
    return const <String, String>{};
  }

  return <String, String>{
    'SDKROOT': sdkRoot,
    'MACOSX_DEPLOYMENT_TARGET':
        Platform.environment['MACOSX_DEPLOYMENT_TARGET'] ?? '10.15',
  };
}

List<String> _macosCargoTargetFlag(NexaHttpNativeTarget target) {
  final triple = target.rustTargetTriple;
  if (triple == null || triple.isEmpty) {
    return const <String>[];
  }
  if (_isHostNativeMacosTarget(target)) {
    return const <String>[];
  }
  return <String>['--target', triple];
}

String _builtArtifactPathForMacosTarget(
  String sourceDir,
  NexaHttpNativeTarget target,
) {
  final workspaceRoot = p.normalize(p.join(sourceDir, '..', '..', '..', '..'));
  if (_isHostNativeMacosTarget(target)) {
    return p.join(
      workspaceRoot,
      'target',
      'debug',
      target.sourceArtifactFileName,
    );
  }
  return p.join(
    workspaceRoot,
    'target',
    target.rustTargetTriple!,
    'debug',
    target.sourceArtifactFileName,
  );
}

bool _isHostNativeMacosTarget(NexaHttpNativeTarget target) {
  if (target.targetOS != 'macos') {
    return false;
  }
  final currentArchitecture = switch (ffi.Abi.current()) {
    ffi.Abi.macosArm64 => 'arm64',
    ffi.Abi.macosX64 => 'x64',
    _ => null,
  };
  return currentArchitecture != null &&
      target.targetArchitecture == currentArchitecture;
}

Future<void> _stagePackagedMacosLibrary({
  required String packageRoot,
  required File file,
}) async {
  final packagedFile = File(
    p.join(packageRoot, 'macos', 'Libraries', 'libnexa_http_native.dylib'),
  );
  await packagedFile.parent.create(recursive: true);
  await file.copy(packagedFile.path);
}

Future<String?> _resolveMacosSdkRoot() async {
  final result = await Process.run('xcrun', <String>[
    '--sdk',
    'macosx',
    '--show-sdk-path',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'xcrun',
      const <String>['--sdk', 'macosx', '--show-sdk-path'],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }

  final sdkRoot = '${result.stdout}'.trim();
  return sdkRoot.isEmpty ? null : sdkRoot;
}
