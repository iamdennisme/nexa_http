import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_distribution/nexa_http_distribution.dart';
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

    final defaultSourceDir = p.normalize(
      p.join(
        Directory.fromUri(input.packageRoot).path,
        'native',
        'nexa_http_native_macos_ffi',
      ),
    );
    final mode = resolveNexaHttpNativeArtifactResolutionMode(
      environment: Platform.environment,
      defaultMode: defaultNexaHttpNativeArtifactResolutionMode(
        packageRoot: input.packageRoot,
        defaultSourceDir: defaultSourceDir,
      ),
    );

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      mode: mode,
      packageVersion: packageVersionForRoot(input.packageRoot),
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: null,
      packagedRelativePath: target.packagedRelativePath,
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
      defaultSourceDir: p.normalize(
        p.join(
          Directory.fromUri(input.packageRoot).path,
          'native',
          'nexa_http_native_macos_ffi',
        ),
      ),
      buildDefaultSourceDir: (sourceDir) async {
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
      },
      sourceDirCandidates: target.sourceDirCandidates,
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
  return <String>[
    'build',
    '--manifest-path',
    p.join(sourceDir, 'Cargo.toml'),
    if (target.rustTargetTriple != null) ...<String>[
      '--target',
      target.rustTargetTriple!,
    ],
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
